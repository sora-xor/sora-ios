// Copyright (c) 2026, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFUtils
import XCTest
@testable import SoraPassport

final class WalletOwnerPINIntentTests: XCTestCase {
    private final class Fixture {
        let keys = IntentFaultKeychain()
        let settings = InMemorySettingsManager()
        lazy var gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        lazy var owner = WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate)

        func prepared(_ byte: UInt8 = 0x21) throws -> PreparedAccount {
            let mnemonic = try IRMnemonicCreator(language: .english)
                .mnemonic(fromEntropy: Data(repeating: byte, count: 16))
            let operation = AccountOperationFactory(keystore: keys, recoveryGate: gate)
                .prepareAccountOperation(request: AccountCreationRequest(username: "Public test fixture",
                    type: .sora, derivationPath: "", cryptoType: .sr25519), mnemonic: mnemonic)
            operation.start()
            return try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }

        func insert(_ byte: UInt8 = 0x21, claim: Bool = true) throws -> AccountItem {
            let prepared = try prepared(byte)
            if claim {
                try prepared.prepareInitialPINSetup(keystore: keys, settings: settings, operationID: UUID())
            }
            try prepared.persist(to: keys)
            return prepared.account
        }
    }

    func testLostPendingPreferencesCannotBindThePreviousInstallPIN() throws {
        let fixture = Fixture()
        try fixture.keys.saveKey(Data("111111".utf8), with: KeystoreTag.pincode.rawValue)
        WalletPendingPinSetup.begin(fixture.settings)
        let account = try fixture.insert()
        // The database and Keychain commit survived, but the defaults write did not.
        fixture.settings.removeAll()
        XCTAssertTrue(try fixture.owner.requiresInitialSetup(accounts: [account]))
        XCTAssertThrowsError(try fixture.owner.authenticateCurrent("111111", accounts: [account]))
        XCTAssertThrowsError(try fixture.owner.prepareAuthentication(currentAccounts: { [account] }))
        let retry = try fixture.prepared()
        try retry.prepareOwnershipBinding(keystore: fixture.keys, settings: fixture.settings)
        XCTAssertFalse(try fixture.keys.checkKey(for: account.address + WalletOwnerPIN.bindingSuffix))
        XCTAssertFalse(try fixture.keys.checkKey(for: WalletOwnerPIN.rebindPrefix + account.address))
        try fixture.owner.setInitialPIN("222222", accounts: [account])
        XCTAssertEqual(try fixture.owner.verifyRetained("222222", addresses: [account.address]), [account.address])
        XCTAssertThrowsError(try fixture.owner.verifyRetained("111111", addresses: [account.address]))
    }

    func testStalePendingTrueCannotAuthorizeAnotherInitialPIN() throws {
        let fixture = Fixture()
        let account = try fixture.insert()
        try fixture.owner.setInitialPIN("222222", accounts: [account])
        // A rollback of only preferences brings the old hint back after success.
        WalletPendingPinSetup.begin(fixture.settings)
        XCTAssertFalse(try fixture.owner.requiresInitialSetup(accounts: [account]))
        XCTAssertThrowsError(try fixture.owner.setInitialPIN("333333", accounts: [account]))
        XCTAssertEqual(try fixture.keys.fetchKey(for: KeystoreTag.pincode.rawValue), Data("222222".utf8))
        XCTAssertNoThrow(try fixture.owner.authenticateCurrent("222222", accounts: [account]))
        XCTAssertEqual(try fixture.owner.verifyRetained("222222", addresses: [account.address]), [account.address])
    }

    func testAnUnfinishedPriorInstallClaimCannotAuthorizeOtherIdentities() throws {
        let fixture = Fixture()
        let abandoned = try fixture.insert(0x22)
        let tag = WalletOwnerPIN.setupPrefix + abandoned.address
        let original = try fixture.keys.fetchKey(for: tag)
        fixture.settings.removeAll()
        let current = try fixture.insert(0x23)
        try fixture.owner.setInitialPIN("333333", accounts: [current])
        XCTAssertEqual(try fixture.keys.fetchKey(for: tag), original)
        XCTAssertNoThrow(try fixture.owner.prepareAuthentication(currentAccounts: { [current] }))
        XCTAssertThrowsError(try fixture.owner.setInitialPIN("444444", accounts: [current, abandoned]))
        XCTAssertThrowsError(try fixture.owner.verifyRetained("333333", addresses: [abandoned.address]))
        XCTAssertEqual(try fixture.keys.fetchKey(for: KeystoreTag.pincode.rawValue), Data("333333".utf8))
    }

    func testImportAfterSetupConsumesAnOrphanClaimOnlyAfterRowCommit() throws {
        let fixture = Fixture()
        let abandoned = try fixture.insert(0x24)
        let orphanTag = WalletOwnerPIN.setupPrefix + abandoned.address
        let orphan = try fixture.keys.fetchKey(for: orphanTag)
        let current = try fixture.insert(0x25)
        try fixture.owner.setInitialPIN("333333", accounts: [current])
        let imported = try fixture.prepared(0x24)
        try imported.prepareOwnershipBinding(keystore: fixture.keys, settings: fixture.settings,
                                             existingAccounts: [current])
        XCTAssertEqual(try fixture.keys.fetchKey(for: orphanTag), orphan)
        // No row means the old intent is preserved, not silently consumed.
        try fixture.owner.settleRebindings(currentAddresses: [current.address])
        XCTAssertEqual(try fixture.keys.fetchKey(for: orphanTag), orphan)
        try imported.prepareOwnershipBinding(keystore: fixture.keys, settings: fixture.settings,
                                             existingAccounts: [current])
        try fixture.owner.settleRebindings(currentAddresses: [current.address, abandoned.address])
        XCTAssertFalse(try fixture.keys.checkKey(for: orphanTag))
        XCTAssertFalse(try fixture.owner.requiresInitialSetup(accounts: [current, abandoned]))
        XCTAssertEqual(try fixture.owner.verifyRetained("333333", addresses: [abandoned.address]), [abandoned.address])
    }

    func testFailedDurableClaimStopsBeforeNewKeyPersistence() throws {
        let fixture = Fixture()
        try fixture.keys.saveKey(Data("111111".utf8), with: KeystoreTag.pincode.rawValue)
        let prepared = try fixture.prepared()
        fixture.keys.failWriteOnce = WalletOwnerPIN.setupPrefix + prepared.account.address
        XCTAssertThrowsError(try prepared.prepareInitialPINSetup(keystore: fixture.keys,
            settings: fixture.settings, operationID: UUID()))
        XCTAssertEqual(try fixture.keys.allKeyIdentifiers(), [KeystoreTag.pincode.rawValue])
        XCTAssertEqual(try fixture.keys.fetchKey(for: KeystoreTag.pincode.rawValue), Data("111111".utf8))
    }

    func testInitialPINConsumesOnlyItsExactIntentAfterEveryInterruptedMutation() throws {
        for interruption in 1...5 {
            let fixture = Fixture()
            try fixture.keys.saveKey(Data("111111".utf8), with: KeystoreTag.pincode.rawValue)
            let account = try fixture.insert()
            let originalSecret = try fixture.keys.fetchSecretKeyForAddress(account.address)
            fixture.keys.mutations = 0
            fixture.keys.failMutation = interruption
            XCTAssertThrowsError(try fixture.owner.setInitialPIN("222222", accounts: [account]))
            fixture.keys.failMutation = nil
            fixture.settings.removeAll()
            try fixture.owner.recoverRotation()
            if interruption == 1 {
                XCTAssertTrue(try fixture.owner.requiresInitialSetup(accounts: [account]))
                XCTAssertThrowsError(try fixture.owner.authenticateCurrent("111111", accounts: [account]))
            }
            try fixture.owner.setInitialPIN("222222", accounts: [account])
            XCTAssertFalse(try fixture.owner.requiresInitialSetup(accounts: [account]))
            XCTAssertFalse(try fixture.keys.checkKey(for: WalletOwnerPIN.rotationTag))
            XCTAssertEqual(try fixture.keys.fetchSecretKeyForAddress(account.address), originalSecret)
            XCTAssertEqual(try fixture.owner.verifyRetained("222222", addresses: [account.address]), [account.address])
        }
    }

    func testFailedReadbackKeepsTheRotationRecoverable() throws {
        for phase in ["journal", "binding", "pincode"] {
            let fixture = Fixture()
            let account = try fixture.insert()
            let tag = phase == "journal" ? WalletOwnerPIN.rotationTag :
                (phase == "binding" ? account.address + WalletOwnerPIN.bindingSuffix : KeystoreTag.pincode.rawValue)
            fixture.keys.failReadAfterWriteOnce = tag
            XCTAssertThrowsError(try fixture.owner.setInitialPIN("222222", accounts: [account]))
            XCTAssertTrue(try fixture.keys.checkKey(for: WalletOwnerPIN.rotationTag))
            try fixture.owner.recoverRotation()
            XCTAssertFalse(try fixture.owner.requiresInitialSetup(accounts: [account]))
            XCTAssertNoThrow(try fixture.owner.authenticateCurrent("222222", accounts: [account]))
        }
    }

    func testRetainedDiscoveryWithoutOwnerGrantCannotMintAnInitialSetupIntent() throws {
        let fixture = Fixture()
        let account = try fixture.insert(claim: false)
        let wallet = try XCTUnwrap(RetainedKeychainWalletDiscovery.prove(address: account.address,
            keystore: fixture.keys, recoveryGate: fixture.gate))
        let retained = try RetainedKeychainWalletDiscovery.preparedAccount(for: wallet, username: "Retained",
            keystore: fixture.keys, recoveryGate: fixture.gate)
        retained.restrictToRetainedOwnership(nil)
        try retained.prepareInitialPINSetup(keystore: fixture.keys, settings: fixture.settings, operationID: UUID())
        XCTAssertFalse(try fixture.owner.requiresInitialSetup(accounts: [account]))
        XCTAssertThrowsError(try fixture.owner.setInitialPIN("333333", accounts: [account]))
    }

    func testCommittedRestoreIsReconciledAfterBindingPublicationFailure() throws {
        let fixture = Fixture()
        let account = try fixture.insert(claim: false)
        try fixture.keys.saveKey(JSONEncoder().encode(WalletOwnerPIN.Binding(pin: "111111")),
                                 with: account.address + WalletOwnerPIN.bindingSuffix)
        try fixture.keys.saveKey(Data("222222".utf8), with: KeystoreTag.pincode.rawValue)
        let grant = try fixture.owner.authorizeRetained("111111", addresses: [account.address])
        let wallet = try XCTUnwrap(RetainedKeychainWalletDiscovery.prove(address: account.address,
            keystore: fixture.keys, recoveryGate: fixture.gate))
        let prepared = try RetainedKeychainWalletDiscovery.preparedAccount(for: wallet, username: "Restored",
            keystore: fixture.keys, recoveryGate: fixture.gate)
        prepared.restrictToRetainedOwnership(grant)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = try WalletAccountCommitJournalStore(baseURL: directory, recoveryGate: fixture.gate)
        let facade = UserDataStorageTestFacade()
        let coordinator = WalletLifecycleCoordinator(recoveryGate: fixture.gate)
        let selection = SelectedWalletSettings(storageFacade: facade, operationQueue: OperationQueue(),
            legacySettings: fixture.settings, walletAccountCommitJournalStoreFactory: { journal },
            lifecycleCoordinator: coordinator, recoveryGate: fixture.gate, keystore: fixture.keys)
        fixture.keys.failWriteOnce = account.address + WalletOwnerPIN.bindingSuffix
        let lease = coordinator.acquire()
        let finished = expectation(description: "Committed row with failed binding publication")
        var callback: Result<AccountItem, Error>?
        selection.performInsertAndSelect(prepared: prepared, persistSecrets: {
            try fixture.owner.prepareRebinding(address: account.address, to: "111111")
            try prepared.persist(to: fixture.keys)
        }, lifecycleLease: lease) { result in
            callback = result
            lease.release()
            finished.fulfill()
        }
        wait(for: [finished], timeout: 10)
        XCTAssertThrowsError(try XCTUnwrap(callback).get())
        let current = try WalletAccountAddresses.accounts(storageFacade: facade)
        XCTAssertEqual(current.map(\.address), [account.address])
        XCTAssertTrue(try journal.unresolved().isEmpty)
        XCTAssertThrowsError(try fixture.owner.prepareAuthentication(currentAccounts: { current }))
        // The same in-session reconciliation used by the flow observes the row
        // even though the insert callback failed, then finishes the correct PIN.
        try fixture.owner.settleRebindings(currentAddresses: Set(current.map(\.address)))
        let committed = WalletRetainedWalletRestoreFlow.committedAddresses(current: current,
            authorized: grant.addresses, existingBefore: [], welcomeBack: true)
        XCTAssertEqual(committed, [account.address])
        try fixture.owner.setInitialPIN("111111", accounts: current)
        XCTAssertFalse(try fixture.owner.requiresInitialSetup(accounts: current))
        XCTAssertEqual(try fixture.keys.fetchKey(for: KeystoreTag.pincode.rawValue), Data("111111".utf8))
        XCTAssertNoThrow(try fixture.owner.prepareAuthentication(currentAccounts: { current }))
    }
}

private final class IntentFaultKeychain: KeystoreProtocol {
    let base = InMemoryKeychain()
    var failMutation: Int?
    var mutations = 0
    var failWriteOnce: String?
    var failReadAfterWriteOnce: String?
    private var pendingReadFailure: String?

    private func beforeWrite(_ tag: String) throws {
        mutations += 1
        if mutations == failMutation { throw WalletOwnerPIN.Failure.persistenceFailed }
        if failWriteOnce == tag {
            failWriteOnce = nil
            throw WalletOwnerPIN.Failure.persistenceFailed
        }
    }
    private func afterWrite(_ tag: String) {
        if failReadAfterWriteOnce == tag {
            failReadAfterWriteOnce = nil
            pendingReadFailure = tag
        }
    }
    func addKey(_ key: Data, with identifier: String) throws {
        try beforeWrite(identifier); try base.addKey(key, with: identifier); afterWrite(identifier)
    }
    func updateKey(_ key: Data, with identifier: String) throws {
        try beforeWrite(identifier); try base.updateKey(key, with: identifier); afterWrite(identifier)
    }
    func deleteKey(for identifier: String) throws { try beforeWrite(identifier); try base.deleteKey(for: identifier) }
    func fetchKey(for identifier: String) throws -> Data {
        if pendingReadFailure == identifier {
            pendingReadFailure = nil
            throw WalletOwnerPIN.Failure.persistenceFailed
        }
        return try base.fetchKey(for: identifier)
    }
    func checkKey(for identifier: String) throws -> Bool { try base.checkKey(for: identifier) }
    func allKeyIdentifiers() throws -> [String] { try base.allKeyIdentifiers() }
}
