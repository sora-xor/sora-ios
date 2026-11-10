// Copyright (c) 2026, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import UIKit
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFUtils
import XCTest
@testable import SoraPassport

final class WalletCredentialRepairTests: XCTestCase {
    fileprivate final class Fixture {
        let keys = RepairFaultKeychain()
        let settings = InMemorySettingsManager()
        lazy var gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false },
            credentialRepairPending: { try self.keys.checkKey(for: WalletCredentialRepair.pendingTag) })
        lazy var coordinator = WalletLifecycleCoordinator(recoveryGate: gate)
        lazy var service = WalletCredentialRepair(keystore: keys, settings: settings,
            recoveryGate: gate, lifecycleCoordinator: coordinator, activeSnapshot: { nil })
        let phrase: String

        init(phrase: String = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about") {
            self.phrase = phrase
        }

        func prepared(_ type: CryptoType = .sr25519, path: String = "//repair") throws -> PreparedAccount {
            let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: phrase)
            let operation = AccountOperationFactory(keystore: keys, recoveryGate: gate)
                .prepareAccountOperation(request: AccountCreationRequest(username: "Public repair fixture",
                    type: .sora, derivationPath: path, cryptoType: type), mnemonic: mnemonic)
            operation.start()
            return try XCTUnwrap(operation.result).get()
        }

        func broken(_ type: CryptoType = .sr25519) throws -> (AccountItem, [String: Data]) {
            let account = try prepared(type).account
            try keys.saveKey(Data("246810".utf8), with: KeystoreTag.pincode.rawValue)
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

        func assertWorking(_ account: AccountItem, file: StaticString = #filePath, line: UInt = #line) throws {
            let secret = try XCTUnwrap(keys.fetchSecretKeyForAddress(account.address), file: file, line: line)
            XCTAssertNoThrow(try LegacySoraIdentityValidator.validateSigningSecret(address: account.address,
                publicKey: account.publicKeyData, cryptoType: account.cryptoType,
                networkType: account.networkType, secret: secret, recoveryGate: gate), file: file, line: line)
            XCTAssertFalse(try service.hasPendingRepair(), file: file, line: line)
            let owner = WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate)
            XCTAssertEqual(try owner.verifyRetained("246810", addresses: [account.address]), [account.address], file: file, line: line)
        }

        func assertPreserved(_ originals: [String: Data], file: StaticString = #filePath, line: UInt = #line) throws {
            let preserved = try keys.allKeyIdentifiers().filter { $0.hasPrefix(WalletCredentialRepair.quarantinePrefix) }
                .map { try keys.fetchKey(for: $0) }
            for value in originals.values {
                XCTAssertTrue(preserved.contains(value), "Every replaced original survives", file: file, line: line)
            }
        }
    }

    func testExplicitConfirmationAndActualAppPINAreRequired() throws {
        let f = Fixture(); let (account, originals) = try f.broken()
        XCTAssertThrowsError(try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] },
            pin: "246810", explicitlyConfirmed: false))
        XCTAssertThrowsError(try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] },
            pin: "135790", explicitlyConfirmed: true), "The wallet's former owner PIN is not the app PIN")
        for (tag, bytes) in originals { XCTAssertEqual(try f.keys.fetchKey(for: tag), bytes) }
        XCTAssertFalse(try f.service.hasPendingRepair())
        XCTAssertFalse(try f.keys.allKeyIdentifiers().contains { $0.hasPrefix(WalletCredentialRepair.quarantinePrefix) })
    }

    func testUnfinishedForeignJournalsRefuseRepairAndResumeWithoutCredentialWrites() throws {
        for migration in [false, true] {
            for pending in [false, true] {
                let f = Fixture(); let (account, _) = try f.broken()
                if pending {
                    f.keys.failAfterWrite = { $0 == WalletCredentialRepair.pendingTag }
                    XCTAssertThrowsError(try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] },
                        pin: "246810", explicitlyConfirmed: true))
                    f.keys.failAfterWrite = nil
                }
                let prepared = try f.prepared()
                let before = try Dictionary(uniqueKeysWithValues: f.keys.allKeyIdentifiers().map {
                    ($0, try f.keys.fetchKey(for: $0))
                })
                let gate = WalletRecoveryCapabilityGate(settings: f.settings,
                    unresolvedMigrationJournal: { migration },
                    unresolvedWalletCommitJournal: { !migration },
                    credentialRepairPending: { try f.service.hasPendingRepair() })
                let service = WalletCredentialRepair(keystore: f.keys, settings: f.settings,
                    recoveryGate: gate, lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate), activeSnapshot: { nil })
                if pending {
                    XCTAssertThrowsError(try service.retryPending(account: account, currentAccounts: { [account] }))
                } else {
                    XCTAssertThrowsError(try service.repair(prepared: prepared, currentAccounts: { [account] },
                        pin: "246810", explicitlyConfirmed: true))
                }
                let after = try Dictionary(uniqueKeysWithValues: f.keys.allKeyIdentifiers().map {
                    ($0, try f.keys.fetchKey(for: $0))
                })
                XCTAssertEqual(before, after)
            }
        }
    }

    func testWrongAccountWatchOnlyAndRetainedProofCannotAuthorizeRepair() throws {
        let f = Fixture(); let (account, originals) = try f.broken()
        XCTAssertThrowsError(try f.service.repair(prepared: f.prepared(path: "//other"), currentAccounts: { [account] },
            pin: "246810", explicitlyConfirmed: true))
        f.settings.set(value: true, for: "wallet.watchOnly.\(account.address)")
        XCTAssertThrowsError(try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] },
            pin: "246810", explicitlyConfirmed: true))
        f.settings.removeAll()
        let untrusted = try f.prepared()
        untrusted.restrictToRetainedOwnership(nil)
        XCTAssertThrowsError(try f.service.repair(prepared: untrusted, currentAccounts: { [account] },
            pin: "246810", explicitlyConfirmed: true))
        for (tag, bytes) in originals { XCTAssertEqual(try f.keys.fetchKey(for: tag), bytes) }
    }

    func testRecordedWatchOnlyStillBlocksRepairAfterDefaultsAreLost() throws {
        let f = Fixture(); let (account, originals) = try f.broken()
        let snapshot = WalletNetworkSnapshot(schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: account.address,
            wallets: [WalletIdentity(id: account.address, displayName: account.username,
                existingSoraAddress: account.address, secretSource: .watchOnly)],
            accounts: [], createdAt: Date())
        let service = WalletCredentialRepair(keystore: f.keys, settings: f.settings,
            recoveryGate: f.gate, lifecycleCoordinator: f.coordinator, activeSnapshot: { snapshot })
        XCTAssertThrowsError(try service.repair(prepared: f.prepared(), currentAccounts: { [account] },
            pin: "246810", explicitlyConfirmed: true)) { error in
            guard case WalletCredentialRepair.Failure.watchOnly = error else { return XCTFail("Expected watch-only refusal") }
        }
        for (tag, bytes) in originals { XCTAssertEqual(try f.keys.fetchKey(for: tag), bytes) }
        XCTAssertFalse(try service.hasPendingRepair())
    }

    func testPhraseRepairsEachCryptoTypeAndPreservesEveryReplacedByte() throws {
        for type in [CryptoType.sr25519, .ed25519, .ecdsa] {
            let f = Fixture(); let (account, originals) = try f.broken(type)
            let prepared = try f.service.prepare(account: account, source: .phrase, text: f.phrase,
                derivationPath: "//repair", backupPassword: "")
            XCTAssertEqual(try f.service.repair(prepared: prepared, currentAccounts: { [account] },
                pin: "246810", explicitlyConfirmed: true), .repaired)
            try f.assertWorking(account); try f.assertPreserved(originals)
            var backup = try WalletBackupMaterial.load(for: account, keystore: f.keys, recoveryGate: f.gate)
            defer { backup.wipe() }
            XCTAssertEqual(backup.phraseStatus, .matching)
            XCTAssertEqual(backup.seedStatus, .matching)
            XCTAssertEqual(try f.keys.allKeyIdentifiers().filter { $0.hasPrefix(WalletCredentialRepair.receiptPrefix) }.count, 1)
        }
    }

    func testWorkingDirectKeyAndConflictingAuxiliariesAreNeverReplaced() throws {
        for type in [CryptoType.sr25519, .ed25519, .ecdsa] {
            let f = Fixture(); let prepared = try f.prepared(type)
            let account = prepared.account
            try prepared.persist(to: f.keys)
            try f.keys.saveKey(Data("246810".utf8), with: KeystoreTag.pincode.rawValue)
            try f.keys.saveKey(Data("//stale".utf8), with: KeystoreTag.deriviationTagForAddress(account.address))
            try f.keys.saveKey(Data([0xa5]), with: KeystoreTag.entropyTagForAddress(account.address))
            let tags = [KeystoreTag.secretKeyTagForAddress(account.address), KeystoreTag.entropyTagForAddress(account.address),
                        KeystoreTag.seedTagForAddress(account.address), KeystoreTag.deriviationTagForAddress(account.address)]
            let original = try tags.map { try f.keys.fetchKey(for: $0) }
            XCTAssertEqual(try f.service.repair(prepared: f.prepared(type), currentAccounts: { [account] },
                pin: "246810", explicitlyConfirmed: true), .supplemented)
            XCTAssertEqual(try tags.map { try f.keys.fetchKey(for: $0) }, original)
            XCTAssertFalse(try f.keys.allKeyIdentifiers().contains { $0.hasPrefix(WalletCredentialRepair.quarantinePrefix) })
            try f.assertWorking(account)
        }
    }

    func testSeedAndJSONRepairUseTheExactAccountAndRecoverableExports() throws {
        for type in [CryptoType.sr25519, .ed25519, .ecdsa] {
            for source in [WalletCredentialRepair.Source.seed, .json] {
                let f = Fixture()
                let good = try f.prepared(type)
                let account = good.account
                var material = try good.credentialRepairMaterial()
                defer { material.wipe() }
                let exportKeys = InMemoryKeychain()
                try good.persist(to: exportKeys)
                let json = try KeystoreExportWrapper(keystore: exportKeys).export(account: account, password: "public-password")
                let text = source == .seed ? try XCTUnwrap(material.seed).map { String(format: "%02x", $0) }.joined() :
                    try XCTUnwrap(String(data: json, encoding: .utf8))
                let (_, originals) = try f.broken(type)
                let prepared = try f.service.prepare(account: account, source: source, text: text,
                    derivationPath: source == .seed ? "//repair" : "", backupPassword: "public-password")
                _ = try f.service.repair(prepared: prepared, currentAccounts: { [account] }, pin: "246810", explicitlyConfirmed: true)
                try f.assertWorking(account); try f.assertPreserved(originals)
                let backup = try KeystoreExportWrapper(keystore: f.keys).export(account: account, password: "new-password")
                let roundTrip = try f.service.prepare(account: account, source: .json,
                    text: XCTUnwrap(String(data: backup, encoding: .utf8)), derivationPath: "", backupPassword: "new-password")
                XCTAssertTrue(WalletCredentialRepair.sameIdentity(roundTrip.account, account))
                roundTrip.discard()
            }
        }
    }

    func testPendingRepairBlocksOrdinaryWalletAccessUntilResume() throws {
        let f = Fixture(); let (account, _) = try f.broken()
        f.keys.failAfterWrite = { $0 == WalletCredentialRepair.pendingTag }
        XCTAssertThrowsError(try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] },
            pin: "246810", explicitlyConfirmed: true))
        XCTAssertThrowsError(try f.gate.requireMutableWalletAccess())
        XCTAssertThrowsError(try WalletCredentialRepair.requireNoPendingRepair(keystore: f.keys))
        XCTAssertNoThrow(try f.gate.requireAuthorizedLifecycleContinuation())
        try f.service.retryPending(account: account, currentAccounts: { [account] })
        XCTAssertNoThrow(try f.gate.requireMutableWalletAccess())
    }

    func testEveryInterruptedMutationResumesWithoutDiscardingOriginals() throws {
        let baseline = Fixture(); let (baselineAccount, _) = try baseline.broken()
        baseline.keys.mutations = 0
        _ = try baseline.service.repair(prepared: baseline.prepared(), currentAccounts: { [baselineAccount] },
            pin: "246810", explicitlyConfirmed: true)
        let transitions = baseline.keys.mutations
        XCTAssertGreaterThan(transitions, 10)
        for stop in 1...transitions {
            let f = Fixture(); let (account, originals) = try f.broken()
            f.keys.mutations = 0; f.keys.failMutation = stop
            XCTAssertThrowsError(try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] },
                pin: "246810", explicitlyConfirmed: true), "Transition \(stop)")
            f.keys.failMutation = nil
            f.settings.removeAll() // Preference rollback cannot lose a Keychain intent.
            if try f.service.hasPendingRepair() {
                try f.service.retryPending(account: account, currentAccounts: { [account] })
            } else {
                _ = try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] },
                    pin: "246810", explicitlyConfirmed: true)
            }
            try f.assertWorking(account); try f.assertPreserved(originals)
        }
    }

    func testAmbiguousWritesAndReadsLeaveAResumableIntent() throws {
        for phase in ["intent", "quarantine", "live", "receipt", "delete"] {
            let f = Fixture(); let (account, originals) = try f.broken()
            f.keys.failAfterWrite = { tag in
                switch phase {
                case "intent": return tag == WalletCredentialRepair.pendingTag
                case "quarantine": return tag.hasPrefix(WalletCredentialRepair.quarantinePrefix)
                case "live": return tag == KeystoreTag.secretKeyTagForAddress(account.address)
                case "receipt": return tag.hasPrefix(WalletCredentialRepair.receiptPrefix)
                default: return false
                }
            }
            if phase == "delete" { f.keys.failDeleteOnce = WalletCredentialRepair.pendingTag }
            XCTAssertThrowsError(try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] },
                pin: "246810", explicitlyConfirmed: true))
            f.keys.failAfterWrite = nil
            XCTAssertTrue(try f.service.hasPendingRepair())
            try f.service.retryPending(account: account, currentAccounts: { [account] })
            try f.assertWorking(account); try f.assertPreserved(originals)
        }
    }

    func testDifferentPINDifferentIdentityAndChangedBytesNeverResumeAnOldIntent() throws {
        for change in ["identity", "pin", "live", "quarantine"] {
            let f = Fixture(); let (account, originals) = try f.broken()
            f.keys.failAfterWrite = { $0 == WalletCredentialRepair.pendingTag }
            XCTAssertThrowsError(try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] },
                pin: "246810", explicitlyConfirmed: true))
            f.keys.failAfterWrite = nil
            var rows = [account]
            if change == "identity" {
                rows = [AccountItem(address: account.address, cryptoType: account.cryptoType,
                    networkType: account.networkType, username: account.username,
                    publicKeyData: Data(repeating: 0x11, count: account.publicKeyData.count),
                    settings: account.settings, order: account.order, isSelected: account.isSelected)]
            }
            if change == "pin" { try f.keys.saveKey(Data("111111".utf8), with: KeystoreTag.pincode.rawValue) }
            if change == "live" { try f.keys.saveKey(Data([0x11]), with: KeystoreTag.secretKeyTagForAddress(account.address)) }
            if change == "quarantine" {
                let data = try f.keys.fetchKey(for: WalletCredentialRepair.pendingTag)
                let value = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                let id = try XCTUnwrap(value["id"] as? String)
                try f.keys.saveKey(Data([0x11]), with: WalletCredentialRepair.quarantinePrefix + id + "-secret")
            }
            let before = try f.keys.snapshot()
            XCTAssertThrowsError(try f.service.retryPending(account: account, currentAccounts: { rows }))
            // A collision in a later quarantine tag may preserve earlier items,
            // but no live item may change before the entire preservation pass.
            for tag in originals.keys { XCTAssertEqual(try f.keys.fetchKey(for: tag), before[tag]) }
            XCTAssertTrue(try f.service.hasPendingRepair())
        }
    }

    func testReinstallArchivesAnOrphanIntentWithoutChangingKeysOrBlockingOtherImports() throws {
        for failArchive in [false, true] {
            let f = Fixture(); let (account, originals) = try f.broken()
            f.keys.failAfterWrite = { $0 == WalletCredentialRepair.pendingTag }
            XCTAssertThrowsError(try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] },
                pin: "246810", explicitlyConfirmed: true))
            let intent = try f.keys.fetchKey(for: WalletCredentialRepair.pendingTag)
            f.settings.removeAll()
            try f.keys.saveKey(Data("111111".utf8), with: KeystoreTag.pincode.rawValue)
            let other = try f.prepared(path: "//different-wallet").account
            if failArchive {
                f.keys.failAfterWrite = { $0.hasPrefix(WalletCredentialRepair.receiptPrefix + "orphaned-") }
                XCTAssertThrowsError(try f.service.resumePending(accounts: [other]))
                XCTAssertTrue(try f.service.hasPendingRepair())
            }
            try f.service.resumePending(accounts: [other])
            XCTAssertFalse(try f.service.hasPendingRepair())
            XCTAssertNoThrow(try f.gate.requireMutableWalletAccess())
            for (tag, bytes) in originals { XCTAssertEqual(try f.keys.fetchKey(for: tag), bytes) }
            let archiveTag = try XCTUnwrap(f.keys.allKeyIdentifiers().first { $0.hasPrefix(WalletCredentialRepair.receiptPrefix + "orphaned-") })
            XCTAssertEqual(try f.keys.fetchKey(for: archiveTag), intent)
            XCTAssertFalse(try f.keys.checkKey(for: other.address + WalletOwnerPIN.bindingSuffix))
        }
    }

    func testCompletedReceiptsCannotRepairAfterAReinstall() throws {
        let f = Fixture(); let (account, _) = try f.broken()
        _ = try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] }, pin: "246810", explicitlyConfirmed: true)
        try f.keys.saveKey(Data([0x17]), with: KeystoreTag.secretKeyTagForAddress(account.address))
        f.settings.removeAll()
        let before = try f.keys.snapshot()
        try f.service.resumePending(accounts: [])
        XCTAssertEqual(try f.keys.snapshot(), before)
    }

    func testUnreadableOriginalStopsBeforeAnyLiveReplacement() throws {
        let f = Fixture(); let (account, originals) = try f.broken()
        f.keys.unreadable = KeystoreTag.entropyTagForAddress(account.address)
        XCTAssertThrowsError(try f.service.repair(prepared: f.prepared(), currentAccounts: { [account] },
            pin: "246810", explicitlyConfirmed: true))
        f.keys.unreadable = nil
        for (tag, bytes) in originals { XCTAssertEqual(try f.keys.fetchKey(for: tag), bytes) }
        XCTAssertFalse(try f.service.hasPendingRepair())
    }

    @MainActor
    func testProductionControllerRequiresConfirmationAndRejectsWrongPIN() async throws {
        let f = Fixture(); let (account, originals) = try f.broken()
        let controller = WalletCredentialRepairViewController(account: account, service: f.service,
            currentAccounts: { [account] }, onSuccess: { _ in XCTFail("Wrong PIN must fail") })
        controller.loadViewIfNeeded()
        let controls = descendants(controller.view)
        let text = try XCTUnwrap(controls.first { $0.accessibilityIdentifier == "wallet-repair-material" } as? UITextView)
        let path = try XCTUnwrap(controls.first { $0.accessibilityIdentifier == "wallet-repair-path" } as? UITextField)
        let pin = try XCTUnwrap(controls.first { $0.accessibilityIdentifier == "wallet-repair-pin" } as? UITextField)
        let status = try XCTUnwrap(controls.first { $0.accessibilityIdentifier == "wallet-repair-status" } as? UILabel)
        text.text = f.phrase; path.text = "//repair"; pin.text = "135790"
        XCTAssertTrue(text.isSecureTextEntry && pin.isSecureTextEntry)
        for (tag, bytes) in originals { XCTAssertEqual(try f.keys.fetchKey(for: tag), bytes) }
        controller.confirmRepair()
        for _ in 0..<200 {
            if status.text != WalletUX.text("Verifying and preserving wallet credentials…") { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNotEqual(status.text, WalletUX.text("Verifying and preserving wallet credentials…"))
        for (tag, bytes) in originals { XCTAssertEqual(try f.keys.fetchKey(for: tag), bytes) }
        XCTAssertEqual(pin.text, "")
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertEqual(text.text, "")
        XCTAssertEqual(path.text, "")
    }

    @MainActor
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
}

fileprivate final class RepairFaultKeychain: KeystoreProtocol {
    let base = InMemoryKeychain()
    var mutations = 0
    var failMutation: Int?
    var failAfterWrite: ((String) -> Bool)?
    var failDeleteOnce: String?
    var unreadable: String?
    private func before(_ tag: String) throws {
        mutations += 1
        if mutations == failMutation { throw WalletCredentialRepair.Failure.persistenceFailed }
    }
    private func after(_ tag: String) throws {
        if failAfterWrite?(tag) == true {
            failAfterWrite = nil
            throw WalletCredentialRepair.Failure.persistenceFailed
        }
    }
    func addKey(_ key: Data, with identifier: String) throws {
        try before(identifier); try base.addKey(key, with: identifier); try after(identifier)
    }
    func updateKey(_ key: Data, with identifier: String) throws {
        try before(identifier); try base.updateKey(key, with: identifier); try after(identifier)
    }
    func deleteKey(for identifier: String) throws {
        try before(identifier)
        if failDeleteOnce == identifier { failDeleteOnce = nil; throw WalletCredentialRepair.Failure.persistenceFailed }
        try base.deleteKey(for: identifier)
    }
    func fetchKey(for identifier: String) throws -> Data {
        if unreadable == identifier { throw WalletCredentialRepair.Failure.persistenceFailed }
        return try base.fetchKey(for: identifier)
    }
    func checkKey(for identifier: String) throws -> Bool { try base.checkKey(for: identifier) }
    func allKeyIdentifiers() throws -> [String] { try base.allKeyIdentifiers() }
    func snapshot() throws -> [String: Data] {
        try Dictionary(uniqueKeysWithValues: allKeyIdentifiers().map { ($0, try fetchKey(for: $0)) })
    }
}

@MainActor
final class CredentialRepairScreenCoverageTests: RootActionFixtureTests {
    private func open(_ f: WalletCredentialRepairTests.Fixture, success: @escaping (AccountItem) -> Void = { _ in }) throws -> WalletCredentialRepairViewController {
        let (account, _) = try f.broken()
        let c = WalletCredentialRepairViewController(account: account, service: f.service, currentAccounts: { [account] }, onSuccess: success)
        mount(c); return c
    }
    private func field(_ id: String, _ c: UIViewController) throws -> UITextField { try XCTUnwrap(all(UITextField.self, c.view).first { $0.accessibilityIdentifier == id }) }
    private func material(_ c: UIViewController) throws -> UITextView { try XCTUnwrap(all(UITextView.self, c.view).first { $0.accessibilityIdentifier == "wallet-repair-material" }) }
    private func status(_ c: UIViewController) throws -> UILabel { try XCTUnwrap(all(UILabel.self, c.view).first { $0.accessibilityIdentifier == "wallet-repair-status" }) }
    func testReviewNamesTheExactWalletBeforeAnyCredentialMutation() async throws {
        let f = WalletCredentialRepairTests.Fixture(); let c = try open(f), before = try f.keys.snapshot()
        try tap("wallet-repair-review", c); await settle()
        XCTAssertEqual(try alert(c).title, "Confirm wallet repair"); XCTAssertTrue(try alert(c).message?.contains(try f.prepared().account.address) == true)
        XCTAssertEqual(try f.keys.snapshot(), before)
    }
    func testCancellingReviewDoesNotStartRepair() async throws {
        let f = WalletCredentialRepairTests.Fixture(); let c = try open(f), before = try f.keys.snapshot()
        try tap("wallet-repair-review", c); await settle(); try await choose("Cancel", c)
        XCTAssertEqual(try f.keys.snapshot(), before); XCTAssertTrue(try button("wallet-repair-review", c).isEnabled)
    }
    func testConfirmedPhraseRepairsTheSameAccountAndClearsEverySensitiveField() async throws {
        let f = WalletCredentialRepairTests.Fixture(); var restored = [AccountItem]()
        let completed = expectation(description: "Confirmed repair completes")
        let c = try open(f) { restored.append($0); completed.fulfill() }
        c.setSuppliedMaterial(source: .phrase, text: f.phrase, derivationPath: "//repair", backupPassword: "unused")
        try field("wallet-repair-pin", c).text = "246810"; c.confirmRepair()
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertEqual(restored.map(\.address), [try f.prepared().account.address]); try f.assertWorking(XCTUnwrap(restored.first))
        XCTAssertEqual(try material(c).text, ""); XCTAssertTrue(all(UITextField.self, c.view).allSatisfy { ($0.text ?? "").isEmpty })
        XCTAssertEqual(try status(c).text, "Wallet credentials repaired."); XCTAssertTrue(try button("wallet-repair-retry", c).isHidden)
    }
    func testShortPhraseRepairWarnsBeforeItContinues() async throws {
        let warned = ApplicationConfig.shared.shortPhraseWarnedAddresses; defer { ApplicationConfig.shared.shortPhraseWarnedAddresses = warned }
        ApplicationConfig.shared.shortPhraseWarnedAddresses = []
        let f = WalletCredentialRepairTests.Fixture(phrase: "abandon abandon ability"); var restored = [AccountItem]()
        let c = try open(f) { restored.append($0) }
        let address = try f.prepared().account.address
        c.setSuppliedMaterial(source: .phrase, text: f.phrase, derivationPath: "//repair", backupPassword: "unused")
        try field("wallet-repair-pin", c).text = "246810"; c.confirmRepair()
        await wait { c.presentedViewController is UIAlertController }
        XCTAssertEqual(try alert(c).title, WalletShortPhraseWarning.title)
        XCTAssertEqual(try alert(c).message, WalletShortPhraseWarning.message + "\n\nPublic repair fixture\n" + address)
        XCTAssertTrue(restored.isEmpty); XCTAssertEqual(try status(c).text, "Wallet credentials repaired.")
        try await choose("OK", c)
        XCTAssertEqual(restored.map(\.address), [address]); try f.assertWorking(XCTUnwrap(restored.first))
        XCTAssertEqual(WalletShortPhraseWarning.warnedAddresses, [address])
    }
    func testChangingSourceClearsPriorMaterialAndShowsOnlyRelevantFields() throws {
        let f = WalletCredentialRepairTests.Fixture(); let c = try open(f)
        c.setSuppliedMaterial(source: .phrase, text: f.phrase, derivationPath: "//repair", backupPassword: "old")
        try tap("wallet-repair-source-2", c)
        XCTAssertEqual(try material(c).text, ""); XCTAssertEqual(try field("wallet-repair-backup-password", c).text, "")
        XCTAssertFalse(try field("wallet-repair-backup-password", c).isHidden); XCTAssertTrue(try field("wallet-repair-path", c).isHidden)
        try tap("wallet-repair-source-1", c)
        XCTAssertTrue(try field("wallet-repair-backup-password", c).isHidden); XCTAssertFalse(try field("wallet-repair-path", c).isHidden)
    }
    func testSelectingDriveDoesNotStartExternalAuthentication() throws {
        let f = WalletCredentialRepairTests.Fixture(); let c = try open(f)
        try tap("wallet-repair-source-3", c)
        XCTAssertTrue(try material(c).isHidden); XCTAssertTrue(try field("wallet-repair-pin", c).isHidden)
        XCTAssertNil(c.presentedViewController); XCTAssertTrue(try button("wallet-repair-review", c).isEnabled)
    }
    func testDriveInitialRouteOnlySelectsTheSourceAndKeepsPinHidden() throws {
        let f = WalletCredentialRepairTests.Fixture(); let (account, _) = try f.broken()
        let c = WalletCredentialRepairViewController(account: account, service: f.service, currentAccounts: { [account] }, onSuccess: { _ in XCTFail("No confirmation") }, startWithDrive: true)
        mount(c); XCTAssertTrue(try material(c).isHidden); XCTAssertTrue(try field("wallet-repair-pin", c).isHidden)
        XCTAssertTrue(try button("wallet-repair-source-3", c).accessibilityTraits.contains(.selected))
    }
    func testInvalidJsonReportsGenericFailureWithoutReplacingCredentials() async throws {
        let f = WalletCredentialRepairTests.Fixture(); let c = try open(f), before = try f.keys.snapshot()
        c.setSuppliedMaterial(source: .json, text: "invalid-json", derivationPath: "", backupPassword: "wrong")
        try field("wallet-repair-pin", c).text = "246810"; c.confirmRepair()
        let label = try status(c); await wait { label.text != "Verifying and preserving wallet credentials…" }
        XCTAssertTrue(label.text?.contains("backup could not be verified") == true)
        XCTAssertEqual(try f.keys.snapshot(), before); XCTAssertEqual(try field("wallet-repair-pin", c).text, "")
    }
    func testBackgroundingClearsSuppliedMaterialAndDismissesReview() async throws {
        let f = WalletCredentialRepairTests.Fixture(); let c = try open(f)
        c.setSuppliedMaterial(source: .json, text: "public fixture", derivationPath: "//repair", backupPassword: "fixture password")
        try field("wallet-repair-pin", c).text = "246810"; try tap("wallet-repair-review", c); await settle()
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil); await settle()
        XCTAssertEqual(try material(c).text, ""); XCTAssertTrue(all(UITextField.self, c.view).allSatisfy { ($0.text ?? "").isEmpty })
        XCTAssertNil(c.presentedViewController)
    }
    func testCaptureNotificationClearsSuppliedBackupImmediately() throws {
        let f = WalletCredentialRepairTests.Fixture(); let c = try open(f)
        c.setSuppliedMaterial(source: .phrase, text: f.phrase, derivationPath: "//repair", backupPassword: "fixture")
        NotificationCenter.default.post(name: UIScreen.capturedDidChangeNotification, object: nil)
        XCTAssertEqual(try material(c).text, ""); XCTAssertTrue(all(UITextField.self, c.view).allSatisfy { ($0.text ?? "").isEmpty })
    }
}
