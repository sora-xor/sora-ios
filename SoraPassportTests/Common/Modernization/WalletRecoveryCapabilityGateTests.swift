// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import Foundation
import SoraKeystore
import XCTest
@testable import SoraPassport

final class WalletRecoveryCapabilityGateTests: XCTestCase {
    private static let nexusXorAssetDefinitionID =
        "6TEAJqbb8oEPmLncoNiMRbLEK6tw"

    func testStickyRecoveryBlocksWithoutInspectingJournals() {
        let settings = InMemorySettingsManager()
        settings.walletMigrationRecoveryRequired = true
        settings.walletMigrationRecoveryReason = "preserved reason"
        var migrationProbeCount = 0
        var commitProbeCount = 0
        let gate = WalletRecoveryCapabilityGate(
            settings: settings,
            unresolvedMigrationJournal: {
                migrationProbeCount += 1
                return false
            },
            unresolvedWalletCommitJournal: {
                commitProbeCount += 1
                return false
            }
        )

        assertRecoveryRequired {
            try gate.requireMutableWalletAccess()
        }
        XCTAssertEqual(migrationProbeCount, 0)
        XCTAssertEqual(commitProbeCount, 0)
        XCTAssertEqual(
            settings.walletMigrationRecoveryReason,
            "preserved reason"
        )
    }

    func testUnresolvedMigrationJournalLatchesRecovery() {
        let settings = InMemorySettingsManager()
        let gate = WalletRecoveryCapabilityGate(
            settings: settings,
            unresolvedMigrationJournal: { true },
            unresolvedWalletCommitJournal: { false }
        )

        assertRecoveryRequired {
            try gate.requireMutableWalletAccess()
        }
        XCTAssertTrue(settings.walletMigrationRecoveryRequired)
        XCTAssertTrue(
            settings.walletMigrationRecoveryReason?
                .contains("wallet database migration") == true
        )
    }

    func testUnresolvedCommitBlocksNewAccessButNotAuthorizedContinuation() {
        let settings = InMemorySettingsManager()
        let gate = WalletRecoveryCapabilityGate(
            settings: settings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { true }
        )

        // A commit journal is expected between the phases of an account
        // create/import already holding its fully checked lifecycle lease.
        XCTAssertNoThrow(
            try gate.requireAuthorizedLifecycleContinuation()
        )
        XCTAssertFalse(settings.walletMigrationRecoveryRequired)

        // A fresh signing or mutation request must wait for that lease. If an
        // unresolved journal remains once it can acquire, it is orphaned and
        // must latch recovery.
        assertRecoveryRequired {
            try gate.requireMutableWalletAccess()
        }
        XCTAssertTrue(settings.walletMigrationRecoveryRequired)
        XCTAssertTrue(
            settings.walletMigrationRecoveryReason?
                .contains("wallet account commit") == true
        )
        assertRecoveryRequired {
            try gate.requireAuthorizedLifecycleContinuation()
        }
    }

    func testVerifiedMigrationNamespaceIsCachedButCommitProbeIsRepeated()
        throws
    {
        let settings = InMemorySettingsManager()
        var migrationProbeCount = 0
        var commitProbeCount = 0
        let gate = WalletRecoveryCapabilityGate(
            settings: settings,
            unresolvedMigrationJournal: {
                migrationProbeCount += 1
                return false
            },
            unresolvedWalletCommitJournal: {
                commitProbeCount += 1
                return false
            }
        )

        try gate.requireMutableWalletAccess()
        try gate.requireMutableWalletAccess()

        XCTAssertEqual(migrationProbeCount, 1)
        XCTAssertEqual(commitProbeCount, 2)
        XCTAssertFalse(settings.walletMigrationRecoveryRequired)
    }

    func testConcurrentFreshAccessReturnsBusyWithoutProbingInflightJournal()
        throws
    {
        let settings = InMemorySettingsManager()
        var commitIsUnresolved = false
        var commitProbeCount = 0
        let gate = WalletRecoveryCapabilityGate(
            settings: settings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: {
                commitProbeCount += 1
                return commitIsUnresolved
            }
        )
        let coordinator = WalletLifecycleCoordinator(
            recoveryGate: gate
        )
        let authorized = try XCTUnwrap(
            coordinator.tryAcquireForMutableWalletAccess()
        )
        XCTAssertEqual(commitProbeCount, 1)

        // Simulate begin() for the authorized create/import. A concurrent
        // request sees the active lease and returns busy without interpreting
        // this legitimate journal as an orphan.
        commitIsUnresolved = true
        XCTAssertNil(
            try coordinator.tryAcquireForMutableWalletAccess()
        )
        XCTAssertEqual(commitProbeCount, 1)
        XCTAssertFalse(settings.walletMigrationRecoveryRequired)

        authorized.release()
        assertRecoveryRequired {
            let unexpected =
                try coordinator.tryAcquireForMutableWalletAccess()
            unexpected?.release()
        }
        XCTAssertEqual(commitProbeCount, 2)
        XCTAssertTrue(settings.walletMigrationRecoveryRequired)
    }

    func testInterruptedMigrationJournalProbeFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        XCTAssertFalse(
            WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(
                storeURL: storeURL
            )
        )

        let attemptID = UUID()
        let attempt = directory
            .appendingPathComponent(
                "WalletMigrationSafety",
                isDirectory: true
            )
            .appendingPathComponent(
                attemptID.uuidString,
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: attempt,
            withIntermediateDirectories: true
        )
        let journal: [String: Any] = [
            "migrationID": attemptID.uuidString,
            "sourceVersion": UserStorageVersion.version1.rawValue,
            "destinationVersion": UserStorageVersion.version2.rawValue,
            "state": "inventoryVerified",
            "updatedAt": "2026-08-02T00:00:00Z",
        ]
        let data = try JSONSerialization.data(
            withJSONObject: journal,
            options: [.sortedKeys]
        )
        try data.write(
            to: attempt.appendingPathComponent("journal.json"),
            options: .atomic
        )

        XCTAssertTrue(
            WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(
                storeURL: storeURL
            )
        )
    }

    func testVerifiedActivatedMigrationAttemptAllowsMutableAccessProbe()
        throws
    {
        let fixture = try makeVerifiedActivatedAttempt()
        defer {
            try? FileManager.default.removeItem(
                at: fixture.directory
            )
        }

        XCTAssertFalse(
            WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(
                storeURL: fixture.storeURL
            )
        )

        let rootResidue = fixture.attemptURL.appendingPathComponent(
            ".durable-capability-root-residue.anchor"
        )
        try Data("retained-old-inode".utf8).write(to: rootResidue)
        XCTAssertTrue(
            WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(
                storeURL: fixture.storeURL
            )
        )
        XCTAssertNotNil(
            try WalletRecoveryMigrationJournalProbe
                .newestVerifiedLegacyStoreBackup(
                    storeURL: fixture.storeURL
                )
        )
        try FileManager.default.removeItem(at: rootResidue)

        let legacyResidue = fixture.legacyDirectory.appendingPathComponent(
            ".durable-capability-legacy-residue.withdrawn"
        )
        try Data("retained-failed-new-inode".utf8).write(
            to: legacyResidue
        )
        XCTAssertTrue(
            WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(
                storeURL: fixture.storeURL
            )
        )
        XCTAssertNotNil(
            try WalletRecoveryMigrationJournalProbe
                .newestVerifiedLegacyStoreBackup(
                    storeURL: fixture.storeURL
                )
        )
        try FileManager.default.removeItem(at: legacyResidue)
        XCTAssertFalse(
            WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(
                storeURL: fixture.storeURL
            )
        )
    }

    func testTamperedActivatedMigrationArtifactFailsClosed() throws {
        let fixture = try makeVerifiedActivatedAttempt()
        defer {
            try? FileManager.default.removeItem(
                at: fixture.directory
            )
        }
        var tampered = try Data(
            contentsOf: fixture.accountManifestURL
        )
        tampered.append(0xff)
        try tampered.write(to: fixture.accountManifestURL)

        XCTAssertTrue(
            WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(
                storeURL: fixture.storeURL
            )
        )
    }

    func testUnexpectedHiddenMigrationNamespaceEntryFailsClosed()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let safetyDirectory = directory.appendingPathComponent(
            "WalletMigrationSafety",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: safetyDirectory,
            withIntermediateDirectories: true
        )
        try Data("unexpected".utf8).write(
            to: safetyDirectory.appendingPathComponent(".orphan")
        )

        XCTAssertTrue(
            WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(
                storeURL: directory.appendingPathComponent(
                    "UserDataModel.sqlite"
                )
            )
        )
    }

    func testNexusHistoryRejectsOversizedExactAmountAndMantissa()
        throws
    {
        let account =
            "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
        let oversized = String(
            repeating: "1",
            count: PIQuantity.maximumWireBytes + 1
        )
        let amountFragments = [
            "\"\(oversized)\"",
            """
            {
              "scale": "1",
              "mantissa": "\(oversized)"
            }
            """,
        ]

        for amountFragment in amountFragments {
            let result = try JSONDecoder().decode(
                NexusJSONValue.self,
                from: Data(
                    """
                    {
                      "body": {
                        "items": [{
                          "transaction_hash":
                            "\(String(repeating: "a", count: 64))",
                          "created_at": "2026-08-02T00:00:00Z",
                          "transaction_status": "Committed",
                          "box": {
                            "json": {
                              "payload": {
                                "variant": "Asset",
                                "value": {
                                  "source":
                                    "\(Self.nexusXorAssetDefinitionID)#\(account)",
                                  "destination": "\(account)",
                                  "object": \(amountFragment)
                                }
                              }
                            }
                          }
                        }]
                      }
                    }
                    """.utf8
                )
            )

            XCTAssertThrowsError(
                try NexusTransferHistoryParser.page(
                    result: result,
                    configuration: .minamoto,
                    account: account,
                    assetDefinitionID: Self.nexusXorAssetDefinitionID
                )
            ) { error in
                guard case NexusToriiError.invalidResponse = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }

    func testSora2DefinitivePreTransportFailureRemovesReservation()
        throws
    {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = try Sora2PendingSubmissionStore(
            baseURL: directory
        )
        let pending = try store.stage(
            account: "sora-account",
            hash: String(repeating: "ab", count: 32)
        )

        try store.removeBeforeSubmission(pending)

        XCTAssertTrue(try store.all().isEmpty)
        XCTAssertThrowsError(
            try store.removeBeforeSubmission(pending)
        )
    }

    private struct VerifiedAttemptFixture {
        let directory: URL
        let storeURL: URL
        let accountManifestURL: URL
        let attemptURL: URL
        let legacyDirectory: URL
    }

    private func makeVerifiedActivatedAttempt() throws
        -> VerifiedAttemptFixture
    {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = directory.appendingPathComponent(
            "UserDataModel.sqlite"
        )
        let attemptID = UUID()
        let attempt = directory
            .appendingPathComponent(
                "WalletMigrationSafety",
                isDirectory: true
            )
            .appendingPathComponent(
                attemptID.uuidString,
                isDirectory: true
            )
        let legacyDirectory = attempt.appendingPathComponent(
            "legacy-store",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: legacyDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: attempt.appendingPathComponent(
                "staging",
                isDirectory: true
            ),
            withIntermediateDirectories: false
        )

        let accountManifestURL = attempt.appendingPathComponent(
            "account-manifest.json"
        )
        let settingsURL = attempt.appendingPathComponent(
            "settings-backup.plist"
        )
        let retainedStoreURL = legacyDirectory.appendingPathComponent(
            storeURL.lastPathComponent
        )
        try Data("[]".utf8).write(to: accountManifestURL)
        try Data("settings".utf8).write(to: settingsURL)
        let retainedStore = Data([0x53, 0x51, 0x4c, 0x69])
        try retainedStore.write(to: retainedStoreURL)

        let backupManifestURL = legacyDirectory.appendingPathComponent(
            "backup-manifest.json"
        )
        let backupRecords: [[String: Any]] = [
            artifactRecord(
                fileName: storeURL.lastPathComponent,
                data: retainedStore
            ),
        ]
        try JSONSerialization.data(
            withJSONObject: backupRecords,
            options: [.sortedKeys]
        ).write(to: backupManifestURL)

        let artifacts: [[String: Any]] = try [
            ("account-manifest.json", accountManifestURL),
            ("settings-backup.plist", settingsURL),
            ("backup-manifest.json", backupManifestURL),
        ].map { name, url in
            artifactRecord(
                fileName: name,
                data: try Data(contentsOf: url)
            )
        }
        let journal: [String: Any] = [
            "migrationID": attemptID.uuidString,
            "sourceVersion": UserStorageVersion.version1.rawValue,
            "destinationVersion":
                UserStorageVersion.version2.rawValue,
            "state": "activated",
            "updatedAt": "2026-08-02T00:00:00Z",
            "safetyArtifacts": artifacts,
        ]
        try JSONSerialization.data(
            withJSONObject: journal,
            options: [.sortedKeys]
        ).write(to: attempt.appendingPathComponent("journal.json"))

        return VerifiedAttemptFixture(
            directory: directory,
            storeURL: storeURL,
            accountManifestURL: accountManifestURL,
            attemptURL: attempt,
            legacyDirectory: legacyDirectory
        )
    }

    private func artifactRecord(
        fileName: String,
        data: Data
    ) -> [String: Any] {
        [
            "fileName": fileName,
            "byteCount": data.count,
            "sha256": Data(SHA256.hash(data: data))
                .map { String(format: "%02x", $0) }
                .joined(),
        ]
    }

    private func assertRecoveryRequired(
        _ body: () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try body(),
            file: file,
            line: line
        ) { error in
            guard
                case WalletNetworkMigrationError
                    .walletRecoveryRequired = error
            else {
                return XCTFail(
                    "Unexpected error: \(error)",
                    file: file,
                    line: line
                )
            }
        }
    }
}
