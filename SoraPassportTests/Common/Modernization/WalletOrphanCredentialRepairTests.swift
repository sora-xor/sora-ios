// Copyright (c) 2026, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFUtils
import XCTest
@testable import SoraPassport

final class WalletOrphanCredentialRepairTests: XCTestCase {
    private final class Fixture {
        let keys = OrphanRepairFaultKeychain()
        let settings = InMemorySettingsManager()
        let facade = UserDataStorageTestFacade()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        lazy var gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: {
                try !WalletAccountCommitJournalStore(baseURL: self.directory).unresolved().isEmpty
            }, credentialRepairPending: { try self.keys.checkKey(for: WalletCredentialRepair.pendingTag) })
        lazy var coordinator = WalletLifecycleCoordinator(recoveryGate: gate)
        lazy var service = WalletCredentialRepair(keystore: keys, settings: settings,
            recoveryGate: gate, lifecycleCoordinator: coordinator, activeSnapshot: { nil })
        let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        lazy var selection = SelectedWalletSettings(storageFacade: facade, operationQueue: OperationQueue(),
            legacySettings: settings, walletNetworkSynchronizer: { accounts, selected, lease in
                try WalletNetworkModelMigrator(keystore: self.keys,
                    store: WalletNetworkStore(baseURL: self.directory, recoveryGate: self.gate),
                    settings: self.settings, lifecycleCoordinator: self.coordinator, recoveryGate: self.gate)
                    .migrate(accounts: accounts, selectedAddress: selected, lifecycleLease: lease)
            }, walletAccountCommitJournalStoreFactory: {
                try WalletAccountCommitJournalStore(baseURL: self.directory, recoveryGate: self.gate)
            }, lifecycleCoordinator: coordinator, recoveryGate: gate, keystore: keys)

        init() throws { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        deinit { try? FileManager.default.removeItem(at: directory) }

        func prepared(_ type: CryptoType = .sr25519, path: String = "//orphan") throws -> PreparedAccount {
            let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: phrase)
            let operation = AccountOperationFactory(keystore: keys, recoveryGate: gate)
                .prepareAccountOperation(request: AccountCreationRequest(username: "Public orphan fixture",
                    type: .sora, derivationPath: path, cryptoType: type), mnemonic: mnemonic)
            operation.start()
            return try XCTUnwrap(operation.result).get()
        }
        func rows() throws -> [AccountItem] {
            let repository: CoreDataRepository<AccountItem, CDAccountItem> =
                facade.createRepository(mapper: AnyCoreDataMapper(AccountItemMapper()))
            let operation = repository.fetchAllOperation(with: RepositoryFetchOptions(includesProperties: true, includesSubentities: true))
            OperationQueue().addOperations([operation], waitUntilFinished: true)
            return try XCTUnwrap(operation.result).get()
        }
        func establishCurrentWallet() throws -> AccountItem {
            let prepared = try prepared(path: "//current")
            try prepared.persist(to: keys)
            let account = prepared.account
            let repository: CoreDataRepository<AccountItem, CDAccountItem> =
                facade.createRepository(mapper: AnyCoreDataMapper(AccountItemMapper()))
            let operation = repository.saveOperation({ [account] }, { [] })
            OperationQueue().addOperations([operation], waitUntilFinished: true)
            _ = try XCTUnwrap(operation.result).get()
            try keys.saveKey(Data("246810".utf8), with: KeystoreTag.pincode.rawValue)
            try keys.saveKey(JSONEncoder().encode(WalletOwnerPIN.Binding(pin: "246810")),
                with: account.address + WalletOwnerPIN.bindingSuffix)
            return account
        }
        func broken(_ type: CryptoType = .sr25519) throws -> (AccountItem, [String: Data]) {
            let account = try prepared(type).account
            let originals = [
                KeystoreTag.secretKeyTagForAddress(account.address): Data([0xff]),
                KeystoreTag.entropyTagForAddress(account.address): Data(repeating: 0x25, count: 16),
                KeystoreTag.seedTagForAddress(account.address): Data(repeating: 0x33, count: 32),
                KeystoreTag.deriviationTagForAddress(account.address): Data("//old".utf8),
                account.address + WalletOwnerPIN.bindingSuffix: try JSONEncoder().encode(WalletOwnerPIN.Binding(pin: "135790"))
            ]
            for (tag, bytes) in originals { try keys.saveKey(bytes, with: tag) }
            return (account, originals)
        }
        func run(_ prepared: PreparedAccount, auth: WalletCredentialRepair.ImportAuthentication,
                 confirmed: Bool = true, service: WalletCredentialRepair? = nil) throws -> AccountItem {
            let done = DispatchSemaphore(value: 0)
            var outcome: Result<AccountItem, Error>?
            (service ?? self.service).importMissingAccount(prepared: prepared, currentAccounts: rows,
                authentication: auth, explicitlyConfirmed: confirmed, selection: selection) {
                    outcome = $0; done.signal()
                }
            guard done.wait(timeout: .now() + 20) == .success else {
                throw WalletCredentialRepair.Failure.persistenceFailed
            }
            return try XCTUnwrap(outcome).get()
        }
        func assertRestored(_ account: AccountItem, pin: String, originals: [String: Data],
                            file: StaticString = #filePath, line: UInt = #line) throws {
            XCTAssertTrue(try rows().contains { WalletCredentialRepair.sameIdentity($0, account) }, file: file, line: line)
            let secret = try XCTUnwrap(keys.fetchSecretKeyForAddress(account.address), file: file, line: line)
            try LegacySoraIdentityValidator.validateSigningSecret(address: account.address,
                publicKey: account.publicKeyData, cryptoType: account.cryptoType,
                networkType: account.networkType, secret: secret, recoveryGate: gate)
            let preserved = try keys.allKeyIdentifiers().filter {
                $0.hasPrefix(WalletCredentialRepair.quarantinePrefix)
            }.map { try keys.fetchKey(for: $0) }
            for value in originals.values { XCTAssertTrue(preserved.contains(value), file: file, line: line) }
            let owner = WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate)
            XCTAssertEqual(try owner.verifyRetained(pin, addresses: [account.address]), [account.address], file: file, line: line)
            XCTAssertFalse(try owner.requiresInitialSetup(accounts: rows()), file: file, line: line)
            XCTAssertFalse(try PinViewFactory.needsPostImportPINSetup(keystore: keys, settings: settings,
                accounts: rows()), file: file, line: line)
            XCTAssertFalse(try service.hasPendingRepair(), file: file, line: line)
            XCTAssertTrue(try WalletAccountCommitJournalStore(baseURL: directory, recoveryGate: gate).unresolved().isEmpty, file: file, line: line)
            XCTAssertNoThrow(try gate.requireMutableWalletAccess(), file: file, line: line)
        }
    }

    func testPostImportPINRoutingUsesDurableIntentAndActualPINPresence() throws {
        let f = try Fixture()
        XCTAssertTrue(try PinViewFactory.needsPostImportPINSetup(keystore: f.keys, settings: f.settings, accounts: []))
        let account = try f.prepared().account
        XCTAssertTrue(try PinViewFactory.needsPostImportPINSetup(keystore: f.keys, settings: f.settings, accounts: [account]))
        try f.keys.saveKey(Data("135790".utf8), with: KeystoreTag.pincode.rawValue)
        try WalletOwnerPIN(keystore: f.keys, settings: f.settings, recoveryGate: f.gate)
            .prepareInitialSetup(account: account, operationID: UUID())
        f.settings.removeAll() // A lost cache flag cannot turn pending setup into authentication.
        XCTAssertTrue(try PinViewFactory.needsPostImportPINSetup(keystore: f.keys, settings: f.settings, accounts: [account]))
        let (_, originals) = try f.broken()
        _ = try f.run(f.prepared(), auth: .newPIN("987654", confirmation: "987654"))
        try f.assertRestored(account, pin: "987654", originals: originals)
        XCTAssertFalse(try PinViewFactory.needsPostImportPINSetup(keystore: f.keys, settings: f.settings, accounts: f.rows()))
    }

    func testEstablishedInstallImportsEachCryptoWithActualCurrentPINAndPreservedOriginals() throws {
        for type in [CryptoType.sr25519, .ed25519, .ecdsa] {
            let f = try Fixture(); let other = try f.establishCurrentWallet()
            let otherKey = try f.keys.fetchSecretKeyForAddress(other.address)
            let (account, originals) = try f.broken(type)
            XCTAssertThrowsError(try f.prepared(type).validatePersistence(to: f.keys), "Old add-only import rejects this actual orphan conflict")
            let imported = try f.run(f.prepared(type), auth: .currentPIN("246810"))
            XCTAssertTrue(WalletCredentialRepair.sameIdentity(imported, account))
            XCTAssertEqual(try f.keys.fetchSecretKeyForAddress(other.address), otherKey)
            try f.assertRestored(account, pin: "246810", originals: originals)
        }
    }

    func testEmptyOnboardingChoosesNewPINAndNeverRebindsUnrelatedRetainedWallet() throws {
        for type in [CryptoType.sr25519, .ed25519, .ecdsa] {
            let f = try Fixture()
            let leftover = try f.prepared(path: "//unrelated")
            let leftoverAccount = leftover.account
            try leftover.persist(to: f.keys)
            let leftoverBinding = try JSONEncoder().encode(WalletOwnerPIN.Binding(pin: "135790"))
            try f.keys.saveKey(leftoverBinding, with: leftoverAccount.address + WalletOwnerPIN.bindingSuffix)
            try f.keys.saveKey(Data("135790".utf8), with: KeystoreTag.pincode.rawValue)
            let (account, originals) = try f.broken(type)
            _ = try f.run(f.prepared(type), auth: .newPIN("987654", confirmation: "987654"))
            try f.assertRestored(account, pin: "987654", originals: originals)
            XCTAssertEqual(try f.keys.fetchKey(for: KeystoreTag.pincode.rawValue), Data("987654".utf8))
            XCTAssertEqual(try f.keys.fetchKey(for: leftoverAccount.address + WalletOwnerPIN.bindingSuffix), leftoverBinding)
            XCTAssertEqual(try f.rows().count, 1)
        }
    }

    func testWrongPINConfirmationAndWrongAuthenticationModeWriteNoWalletItems() throws {
        for established in [false, true] {
            let f = try Fixture()
            if established { _ = try f.establishCurrentWallet() }
            else { try f.keys.saveKey(Data("135790".utf8), with: KeystoreTag.pincode.rawValue) }
            let (_, originals) = try f.broken()
            let auth: WalletCredentialRepair.ImportAuthentication = established ? .newPIN("987654", confirmation: "987654") : .currentPIN("135790")
            XCTAssertThrowsError(try f.run(f.prepared(), auth: auth))
            XCTAssertThrowsError(try f.run(f.prepared(), auth: established ? .currentPIN("135790") : .newPIN("987654", confirmation: "987650")))
            XCTAssertThrowsError(try f.run(f.prepared(), auth: established ? .currentPIN("246810") : .newPIN("987654", confirmation: "987654"), confirmed: false))
            for (tag, bytes) in originals { XCTAssertEqual(try f.keys.fetchKey(for: tag), bytes) }
            XCTAssertFalse(try f.service.hasPendingRepair())
            XCTAssertEqual(try f.rows().count, established ? 1 : 0)
        }
    }

    func testRetainedProofWatchOnlyAndExistingIdentityCannotEnterMissingRowRoute() throws {
        let f = try Fixture(); _ = try f.establishCurrentWallet()
        let (account, originals) = try f.broken()
        let untrusted = try f.prepared(); untrusted.restrictToRetainedOwnership(nil)
        XCTAssertThrowsError(try f.run(untrusted, auth: .currentPIN("246810")))
        f.settings.set(value: true, for: "wallet.watchOnly.\(account.address)")
        XCTAssertThrowsError(try f.run(f.prepared(), auth: .currentPIN("246810")))
        f.settings.removeValue(for: "wallet.watchOnly.\(account.address)")
        let snapshot = WalletNetworkSnapshot(schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: account.address, wallets: [WalletIdentity(id: account.address,
                displayName: account.username, existingSoraAddress: account.address, secretSource: .watchOnly)], accounts: [], createdAt: Date())
        let service = WalletCredentialRepair(keystore: f.keys, settings: f.settings, recoveryGate: f.gate,
            lifecycleCoordinator: f.coordinator, activeSnapshot: { snapshot })
        XCTAssertThrowsError(try f.run(f.prepared(), auth: .currentPIN("246810"), service: service))
        for (tag, bytes) in originals { XCTAssertEqual(try f.keys.fetchKey(for: tag), bytes) }
        XCTAssertThrowsError(try f.run(f.prepared(path: "//current"), auth: .currentPIN("246810")))
    }

    func testWorkingOrphanDirectKeyAndMismatchedAuxiliariesRemainAddOnly() throws {
        let f = try Fixture(); _ = try f.establishCurrentWallet()
        let good = try f.prepared(); let account = good.account
        try good.persist(to: f.keys)
        try f.keys.saveKey(Data("//stale".utf8), with: KeystoreTag.deriviationTagForAddress(account.address))
        try f.keys.saveKey(Data([0xa5]), with: KeystoreTag.entropyTagForAddress(account.address))
        let tags = [KeystoreTag.secretKeyTagForAddress(account.address), KeystoreTag.entropyTagForAddress(account.address),
                    KeystoreTag.seedTagForAddress(account.address), KeystoreTag.deriviationTagForAddress(account.address)]
        let before = try tags.map { try f.keys.fetchKey(for: $0) }
        _ = try f.run(f.prepared(), auth: .currentPIN("246810"))
        XCTAssertEqual(try tags.map { try f.keys.fetchKey(for: $0) }, before)
        XCTAssertFalse(try f.keys.allKeyIdentifiers().contains { $0.hasPrefix(WalletCredentialRepair.quarantinePrefix) })
    }

    func testEveryPreInsertionKeychainInterruptionRequiresFreshProofAndPreservesAllOriginals() throws {
        // Stop before every Keychain mutation through the completed repair and
        // new-PIN rotation. Automatic startup cannot create a missing row.
        let baseline = try Fixture(); let (account, _) = try baseline.broken()
        baseline.keys.mutations = 0
        _ = try baseline.run(baseline.prepared(), auth: .newPIN("987654", confirmation: "987654"))
        let count = baseline.keys.mutations
        XCTAssertGreaterThan(count, 15)
        for stop in 1...count {
            let f = try Fixture(); let (_, originals) = try f.broken()
            f.keys.mutations = 0; f.keys.failMutation = stop
            _ = try? f.run(f.prepared(), auth: .newPIN("987654", confirmation: "987654"))
            f.keys.failMutation = nil
            let rows = try f.rows()
            if rows.isEmpty {
                let liveBefore = try Dictionary(uniqueKeysWithValues: originals.keys.map { ($0, try f.keys.loadIfKeyExists($0)) })
                let lease = f.coordinator.acquire()
                try f.service.resumePending(accounts: [])
                lease.release()
                XCTAssertTrue(try f.rows().isEmpty, "Stop \(stop) cannot invent a row")
                for tag in originals.keys { XCTAssertEqual(try f.keys.loadIfKeyExists(tag), liveBefore[tag]!) }
                _ = try f.run(f.prepared(), auth: .newPIN("987654", confirmation: "987654"))
            }
            try f.assertRestored(account, pin: "987654", originals: originals)
        }
    }

    func testOrphanReceiptAfterSecondReinstallCannotActivateOrChangeAnotherWallet() throws {
        let f = try Fixture(); let (_, originals) = try f.broken()
        f.keys.failAfterWrite = { $0 == WalletCredentialRepair.pendingTag }
        XCTAssertThrowsError(try f.run(f.prepared(), auth: .newPIN("987654", confirmation: "987654")))
        f.settings.removeAll()
        let other = try f.establishCurrentWallet()
        let before = try f.keys.snapshot()
        let lease = f.coordinator.acquire()
        try f.service.resumePending(accounts: f.rows())
        lease.release()
        for tag in originals.keys { XCTAssertEqual(try f.keys.fetchKey(for: tag), before[tag]) }
        XCTAssertEqual(try f.rows().map(\.address), [other.address])
        XCTAssertFalse(try f.service.hasPendingRepair())
        XCTAssertTrue(try f.keys.allKeyIdentifiers().contains { $0.hasPrefix(WalletCredentialRepair.receiptPrefix + "orphaned-") })
    }

    func testForeignJournalsAndUnreadableOriginalsBlockMissingRowWrites() throws {
        let f = try Fixture(); let (account, originals) = try f.broken()
        let blockedGate = WalletRecoveryCapabilityGate(settings: f.settings,
            unresolvedMigrationJournal: { true }, unresolvedWalletCommitJournal: { false })
        let blocked = WalletCredentialRepair(keystore: f.keys, settings: f.settings,
            recoveryGate: blockedGate, lifecycleCoordinator: f.coordinator, activeSnapshot: { nil })
        let prepared = try f.prepared()
        XCTAssertThrowsError(try f.run(prepared, auth: .newPIN("987654", confirmation: "987654"), service: blocked))
        f.settings.removeAll()
        f.keys.unreadable = KeystoreTag.entropyTagForAddress(account.address)
        XCTAssertThrowsError(try f.run(f.prepared(), auth: .newPIN("987654", confirmation: "987654")))
        f.keys.unreadable = nil
        for (tag, bytes) in originals { XCTAssertEqual(try f.keys.fetchKey(for: tag), bytes) }
        XCTAssertTrue(try f.rows().isEmpty)
    }
}

private final class OrphanRepairFaultKeychain: KeystoreProtocol {
    private let base = InMemoryKeychain()
    var mutations = 0
    var failMutation: Int?
    var failAfterWrite: ((String) -> Bool)?
    var unreadable: String?
    private func before() throws {
        mutations += 1
        if mutations == failMutation { throw WalletCredentialRepair.Failure.persistenceFailed }
    }
    private func after(_ identifier: String) throws {
        if failAfterWrite?(identifier) == true {
            failAfterWrite = nil
            throw WalletCredentialRepair.Failure.persistenceFailed
        }
    }
    func addKey(_ key: Data, with identifier: String) throws { try before(); try base.addKey(key, with: identifier); try after(identifier) }
    func saveKey(_ key: Data, with identifier: String) throws { try before(); try base.saveKey(key, with: identifier); try after(identifier) }
    func updateKey(_ key: Data, with identifier: String) throws { try before(); try base.updateKey(key, with: identifier); try after(identifier) }
    func deleteKey(for identifier: String) throws { try before(); try base.deleteKey(for: identifier); try after(identifier) }
    func fetchKey(for identifier: String) throws -> Data {
        if unreadable == identifier { throw WalletCredentialRepair.Failure.persistenceFailed }
        return try base.fetchKey(for: identifier)
    }
    func checkKey(for identifier: String) throws -> Bool { try base.checkKey(for: identifier) }
    func allKeyIdentifiers() throws -> [String] { try base.allKeyIdentifiers() }
    func snapshot() throws -> [String: Data] { try Dictionary(uniqueKeysWithValues: allKeyIdentifiers().map { ($0, try fetchKey(for: $0)) }) }
}
