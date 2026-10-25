// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import SoraKeystore
import XCTest
@testable import SoraPassport

/// The interim recovery-exits build (internal TestFlight 3.9.2, 2026102401)
/// left state behind on the phones that used its recovery screen: verified
/// copies of wallet Keychain items under `retired.<archive>.<tag>.retired`,
/// a `pincodeAttempts` Keychain item, a `walletRecovery.archives` setting and
/// files moved into `Application Support/SORA/WalletRecoveryArchive/<id>`.
/// The Welcome back and recovery code that replaced it must read none of
/// these as a wallet and must change or delete none of them.
final class InterimRecoveryLeftoverTests: XCTestCase {
    private let address = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
    private let archiveId = "20261024T071512Z-5B3C9D0E"

    private func retired(_ tag: String) -> String {
        "retired." + archiveId + "." + tag + ".retired"
    }

    private func leftoverKeychain() throws -> RecordingKeychain {
        let keychain = RecordingKeychain()
        let tags = [
            KeystoreTag.entropyTagForAddress(address),
            KeystoreTag.seedTagForAddress(address),
            KeystoreTag.secretKeyTagForAddress(address),
            KeystoreTag.deriviationTagForAddress(address),
            KeystoreTag.pincode.rawValue,
            KeystoreTag.legacyEntropy.rawValue,
            KeystoreTag.legacyUsername.rawValue,
            "privateKey",
            "pincodeAttempts",
        ]
        for (index, tag) in tags.enumerated() {
            try keychain.base.addKey(Data([UInt8(index + 1), 0x5A, 0xA5]), with: retired(tag))
        }
        try keychain.base.addKey(Data(#"{"failures":2}"#.utf8), with: "pincodeAttempts")
        return keychain
    }

    func testRetiredCopiesAndTheAttemptRecordAreNotWallets() throws {
        let keychain = try leftoverKeychain()
        let before = try keychain.bytes()
        let gate = WalletRecoveryCapabilityGate(
            settings: InMemorySettingsManager(),
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }
        )

        XCTAssertFalse(try keychain.hasRetainedWalletKeys())
        XCTAssertFalse(try keychain.hasRetainedWalletMaterial())
        let inventory = try RetainedKeychainWalletDiscovery.inventory(keystore: keychain, recoveryGate: gate)
        XCTAssertTrue(inventory.adoptable.isEmpty)
        XCTAssertEqual(inventory.unprovableAddressCount, 0)
        XCTAssertFalse(WalletRetainedPinGate.hasRetainedPin(keystore: keychain))
        XCTAssertEqual(
            try RetainedKeychainWalletDiscovery.proveGlobalEntropy(keystore: keychain, recoveryGate: gate),
            .absent
        )

        XCTAssertEqual(try keychain.bytes(), before)
        XCTAssertTrue(keychain.added.isEmpty)
        XCTAssertTrue(keychain.updated.isEmpty)
        XCTAssertTrue(keychain.deleted.isEmpty)
    }

    func testTheArchiveSettingIsNotWalletStateAndTheArchiveFilesAreLeftAlone() throws {
        let settings = InMemorySettingsManager()
        settings.set(value: "[\"\(archiveId)\"]", for: "walletRecovery.archives")
        XCTAssertFalse(WalletLocalStateSetAside.walletSettingKeys(in: settings).contains("walletRecovery.archives"))

        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("InterimRecoveryLeftovers-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        let support = root.appendingPathComponent("Application Support", isDirectory: true)
        let store = root.appendingPathComponent("Documents/CoreData/SoraPassport.sqlite")
        let archive = support.appendingPathComponent("SORA/WalletRecoveryArchive/\(archiveId)", isDirectory: true)
        let moved = [
            archive.appendingPathComponent("CoreData/SoraPassport.sqlite"),
            archive.appendingPathComponent("WalletNetworks/networks-v1.json"),
            archive.appendingPathComponent("WalletAccountCommits/.networks-v1.json.tmp"),
            archive.appendingPathComponent("settings.plist"),
            archive.appendingPathComponent("manifest.json"),
        ]
        for file in moved {
            try fileManager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(file.lastPathComponent.utf8).write(to: file)
        }

        let checked = WalletInterruptedWriteCleanup.directories(storeURL: store, applicationSupportURL: support)
        XCTAssertFalse(checked.contains { $0.path.contains("WalletRecoveryArchive") })
        XCTAssertEqual(WalletInterruptedWriteCleanup.run(storeURL: store, applicationSupportURL: support), 0)
        for file in moved {
            XCTAssertEqual(try Data(contentsOf: file), Data(file.lastPathComponent.utf8), file.path)
        }
    }

    /// Ported from the interim build's PIN attempt record: app PIN attempts
    /// are counted in the Keychain (WalletOwnerPIN), so a reinstall, which
    /// deletes settings but keeps Keychain items, resets neither the count
    /// nor an active wait, and the wait keeps growing.
    func testAppPINAttemptsAndTheirWaitOutliveSettingsAndKeepGrowing() throws {
        let keychain = InMemoryKeychain()
        try keychain.addKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)
        var uptime: TimeInterval = 1_000
        func freshInstall() -> WalletOwnerPIN {
            let settings = InMemorySettingsManager()
            return WalletOwnerPIN(
                keystore: keychain,
                settings: settings,
                recoveryGate: WalletRecoveryCapabilityGate(
                    settings: settings,
                    unresolvedMigrationJournal: { false },
                    unresolvedWalletCommitJournal: { false }
                ),
                uptime: { uptime },
                boot: { "boot-1" }
            )
        }
        func assertLocked(_ pin: String, line: UInt = #line) {
            XCTAssertThrowsError(try freshInstall().authenticateCurrent(pin, accounts: []), line: line) { error in
                guard case .locked? = error as? WalletRetainedPinGate.Failure else {
                    return XCTFail("expected a wait, got \(error)", line: line)
                }
            }
        }
        func assertIncorrect(_ pin: String, line: UInt = #line) {
            XCTAssertThrowsError(try freshInstall().authenticateCurrent(pin, accounts: []), line: line) { error in
                guard case .incorrectPin? = error as? WalletRetainedPinGate.Failure else {
                    return XCTFail("expected a wrong PIN, got \(error)", line: line)
                }
            }
        }

        for _ in 0 ..< WalletRetainedPinGate.failuresBeforeWait {
            assertIncorrect("000000")
        }
        // Even the right PIN waits, whatever settings a new install has.
        assertLocked("123456")
        uptime += WalletRetainedPinGate.cooldown(afterFailures: WalletRetainedPinGate.failuresBeforeWait) + 1
        assertIncorrect("000000")
        assertLocked("123456")
        uptime += WalletRetainedPinGate.cooldown(afterFailures: WalletRetainedPinGate.failuresBeforeWait + 1) + 1
        XCTAssertNoThrow(try freshInstall().authenticateCurrent("123456", accounts: []))
        XCTAssertFalse(try keychain.checkKey(for: WalletOwnerPIN.appThrottleTag))
    }
}

/// Fixtures are written through `base` and not recorded.
private final class RecordingKeychain: KeystoreProtocol {
    let base = InMemoryKeychain()
    private(set) var added: [String] = []
    private(set) var updated: [String] = []
    private(set) var deleted: [String] = []

    func addKey(_ key: Data, with identifier: String) throws {
        added.append(identifier)
        try base.addKey(key, with: identifier)
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        updated.append(identifier)
        try base.updateKey(key, with: identifier)
    }

    func fetchKey(for identifier: String) throws -> Data { try base.fetchKey(for: identifier) }
    func checkKey(for identifier: String) throws -> Bool { try base.checkKey(for: identifier) }
    func allKeyIdentifiers() throws -> [String] { try base.allKeyIdentifiers() }

    func deleteKey(for identifier: String) throws {
        deleted.append(identifier)
        try base.deleteKey(for: identifier)
    }

    func bytes() throws -> [String: Data] {
        var result: [String: Data] = [:]
        for identifier in try base.allKeyIdentifiers() {
            result[identifier] = try base.fetchKey(for: identifier)
        }
        return result
    }
}
