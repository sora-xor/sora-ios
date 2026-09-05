// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import Foundation
import XCTest
@testable import SoraPassport

final class WalletRecoveryExporterTests: XCTestCase {

    func testNewestVerifiedBackupIsExportedAndSettingsAreAllowlisted()
        throws
    {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        _ = try makeActivatedAttempt(
            fixture: fixture,
            retainedStore: Data("older-backup".utf8),
            settings: [
                SettingsKey.selectedLocalization.rawValue: "en",
            ],
            updatedAt: "2026-08-02T00:00:00Z"
        )
        let newest = try makeActivatedAttempt(
            fixture: fixture,
            retainedStore: Data("newest-backup".utf8),
            settings: [
                SettingsKey.selectedLocalization.rawValue: "ja",
                SettingsKey.streamToken.rawValue:
                    "must-not-leave-the-device",
            ],
            updatedAt: "2026-08-02T01:00:00Z",
            includeStagingDecoy: true
        )
        let retainedBefore = try Data(
            contentsOf: newest.retainedStoreURL
        )
        let settingsBefore = try Data(
            contentsOf: newest.settingsURL
        )

        let result = try makeExporter(
            fixture: fixture,
            settings: {
                XCTFail(
                    "Live settings must not be read when a verified backup exists"
                )
                return [:]
            }
        ).createRecoveryPackage()

        XCTAssertEqual(
            result.manifest.sourceType,
            .verifiedMigrationLegacyStore
        )
        XCTAssertEqual(
            try record(
                "wallet-store/\(fixture.storeURL.lastPathComponent)",
                in: result.manifest
            ).sha256,
            sha256(Data("newest-backup".utf8))
        )
        let expectedSettings = try WalletRecoveryExporter
            .sanitizedSettingsData(
                from: [
                    SettingsKey.selectedLocalization.rawValue: "ja",
                ]
            )
        XCTAssertEqual(
            try record(
                "settings-backup.plist",
                in: result.manifest
            ).sha256,
            sha256(expectedSettings)
        )
        XCTAssertEqual(
            try Data(contentsOf: newest.retainedStoreURL),
            retainedBefore
        )
        XCTAssertEqual(
            try Data(contentsOf: newest.settingsURL),
            settingsBefore
        )
        try assertZIPArchive(result.packageURL)
        XCTAssertTrue(
            result.manifest.files.allSatisfy {
                !$0.relativeName.contains(newest.attemptID.uuidString)
            }
        )
    }

    func testLiveStoreFallbackCapturesStableSQLiteSidecarsAndSettings()
        throws
    {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let main = Data("live-main".utf8)
        let wal = Data("live-wal".utf8)
        let shm = Data("live-shm".utf8)
        let migrationAccounts = Data(
            "{\"accountAddresses\":[\"sora-account\"],\"schemaVersion\":1}"
                .utf8
        )
        try main.write(to: fixture.storeURL)
        try wal.write(
            to: URL(fileURLWithPath: fixture.storeURL.path + "-wal")
        )
        try shm.write(
            to: URL(fileURLWithPath: fixture.storeURL.path + "-shm")
        )
        let snapshot: [String: Any] = [
            SettingsKey.selectedLocalization.rawValue: "en",
            SettingsKey.tairaEnabled.rawValue: true,
            SettingsKey.tairaPreferenceWasSet.rawValue: true,
            SettingsKey.tairaExplicitPreference.rawValue: "enabled",
            SettingsKey.tairaRemoteDefault.rawValue: false,
            SettingsKey.migratedAccountsV1.rawValue: migrationAccounts,
            SettingsKey.streamToken.rawValue: "private-token",
        ]

        let result = try makeExporter(
            fixture: fixture,
            settings: { snapshot }
        ).createRecoveryPackage()

        XCTAssertEqual(
            result.manifest.sourceType,
            .liveStoreFallback
        )
        XCTAssertEqual(
            try record(
                "wallet-store/\(fixture.storeURL.lastPathComponent)",
                in: result.manifest
            ).sha256,
            sha256(main)
        )
        XCTAssertEqual(
            try record(
                "wallet-store/\(fixture.storeURL.lastPathComponent)-wal",
                in: result.manifest
            ).sha256,
            sha256(wal)
        )
        XCTAssertEqual(
            try record(
                "wallet-store/\(fixture.storeURL.lastPathComponent)-shm",
                in: result.manifest
            ).sha256,
            sha256(shm)
        )
        let expectedSettings = try WalletRecoveryExporter
            .sanitizedSettingsData(
                from: [
                    SettingsKey.selectedLocalization.rawValue: "en",
                    SettingsKey.tairaEnabled.rawValue: true,
                    SettingsKey.tairaPreferenceWasSet.rawValue: true,
                    SettingsKey.tairaExplicitPreference.rawValue: "enabled",
                    SettingsKey.tairaRemoteDefault.rawValue: false,
                    SettingsKey.migratedAccountsV1.rawValue:
                        migrationAccounts,
                ]
            )
        XCTAssertEqual(
            try record(
                "settings-backup.plist",
                in: result.manifest
            ).sha256,
            sha256(expectedSettings)
        )
        try assertZIPArchive(result.packageURL)
    }

    func testUnverifiedStagingStoreIsIgnoredForLiveFallback() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try Data("live-authoritative".utf8).write(
            to: fixture.storeURL
        )
        try makeUnverifiedStagingAttempt(
            fixture: fixture,
            stagedStore: Data("never-export-staging".utf8)
        )

        let result = try makeExporter(
            fixture: fixture,
            settings: { [:] }
        ).createRecoveryPackage()

        XCTAssertEqual(
            result.manifest.sourceType,
            .liveStoreFallback
        )
        XCTAssertEqual(
            try record(
                "wallet-store/\(fixture.storeURL.lastPathComponent)",
                in: result.manifest
            ).sha256,
            sha256(Data("live-authoritative".utf8))
        )
    }

    func testVerifiedFailedMigrationBackupIsPreferredOverLiveFallback()
        throws
    {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try Data("newer-live-after-failure".utf8).write(
            to: fixture.storeURL
        )
        _ = try makeActivatedAttempt(
            fixture: fixture,
            retainedStore: Data("pre-migration-recovery-copy".utf8),
            settings: [:],
            updatedAt: "2026-08-02T00:00:00Z",
            state: "failed",
            failureReason: "destination verification failed",
            includeStagingDecoy: true
        )

        let result = try makeExporter(
            fixture: fixture,
            settings: { [:] }
        ).createRecoveryPackage()

        XCTAssertEqual(
            result.manifest.sourceType,
            .verifiedMigrationLegacyStore
        )
        XCTAssertEqual(
            try record(
                "wallet-store/\(fixture.storeURL.lastPathComponent)",
                in: result.manifest
            ).sha256,
            sha256(Data("pre-migration-recovery-copy".utf8))
        )
    }

    func testTamperedActivatedBackupFailsClosedWithoutLiveFallback()
        throws
    {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try Data("live-must-not-mask-tamper".utf8).write(
            to: fixture.storeURL
        )
        let attempt = try makeActivatedAttempt(
            fixture: fixture,
            retainedStore: Data("verified-before-tamper".utf8),
            settings: [:],
            updatedAt: "2026-08-02T00:00:00Z"
        )
        try Data("tampered".utf8).write(
            to: attempt.retainedStoreURL
        )

        XCTAssertThrowsError(
            try makeExporter(
                fixture: fixture,
                settings: { [:] }
            ).createRecoveryPackage()
        )
        XCTAssertTrue(try publishedPackages(in: fixture).isEmpty)
    }

    func testUnexpectedVerifiedLegacyStoreEntryFailsClosed() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try Data("live-must-not-mask-corruption".utf8).write(
            to: fixture.storeURL
        )
        let attempt = try makeActivatedAttempt(
            fixture: fixture,
            retainedStore: Data("verified".utf8),
            settings: [:],
            updatedAt: "2026-08-02T00:00:00Z"
        )
        try Data("unexpected".utf8).write(
            to: attempt.retainedStoreURL
                .deletingLastPathComponent()
                .appendingPathComponent("unexpected.bin")
        )

        XCTAssertThrowsError(
            try makeExporter(
                fixture: fixture,
                settings: { [:] }
            ).createRecoveryPackage()
        )
        XCTAssertTrue(try publishedPackages(in: fixture).isEmpty)
    }

    func testSymlinkedLiveStoreFailsClosed() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let target = fixture.root.appendingPathComponent(
            "actual.sqlite"
        )
        try Data("target".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(
            at: fixture.storeURL,
            withDestinationURL: target
        )

        XCTAssertThrowsError(
            try makeExporter(
                fixture: fixture,
                settings: { [:] }
            ).createRecoveryPackage()
        )
        XCTAssertTrue(try publishedPackages(in: fixture).isEmpty)
    }

    func testOversizedLiveStoreFailsBeforeCopy() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        XCTAssertTrue(
            FileManager.default.createFile(
                atPath: fixture.storeURL.path,
                contents: Data([0])
            )
        )
        let handle = try FileHandle(
            forWritingTo: fixture.storeURL
        )
        try handle.truncate(
            atOffset: UInt64(512 * 1_024 * 1_024 + 1)
        )
        try handle.close()

        XCTAssertThrowsError(
            try makeExporter(
                fixture: fixture,
                settings: { [:] }
            ).createRecoveryPackage()
        )
        XCTAssertTrue(try publishedPackages(in: fixture).isEmpty)
    }

    func testArchiveCoordinationFailureLeavesNoPublishedArtifact()
        throws
    {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try Data("live".utf8).write(to: fixture.storeURL)
        let exporter = makeExporter(
            fixture: fixture,
            settings: { [:] },
            archiveProvider: { _, _, _ in
                throw WalletRecoveryExportError.publicationFailed
            }
        )

        XCTAssertThrowsError(try exporter.createRecoveryPackage())
        XCTAssertTrue(try publishedPackages(in: fixture).isEmpty)
        XCTAssertTrue(try hiddenStagingEntries(in: fixture).isEmpty)

        let protectionFixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(
                at: protectionFixture.root
            )
        }
        try Data("live".utf8).write(to: protectionFixture.storeURL)
        var didRejectMissingPublishedProtection = false
        let protectionExporter = makeExporter(
            fixture: protectionFixture,
            settings: { [:] },
            protectionClassProvider: { url, fileManager in
                if url.lastPathComponent.hasSuffix(
                    ".sorarecovery.zip"
                ) {
                    didRejectMissingPublishedProtection = true
                    return nil
                }
                return try FileProtectionMetadata.protectionClass(
                    at: url,
                    fileManager: fileManager
                )
            }
        )

        XCTAssertThrowsError(
            try protectionExporter.createRecoveryPackage()
        ) { error in
            guard
                case WalletRecoveryExportError.publicationFailed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(didRejectMissingPublishedProtection)
        XCTAssertTrue(
            try publishedPackages(in: protectionFixture).isEmpty
        )
        XCTAssertTrue(
            try hiddenStagingEntries(in: protectionFixture).isEmpty
        )

        let onDiskMismatchFixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(
                at: onDiskMismatchFixture.root
            )
        }
        try Data("live".utf8).write(
            to: onDiskMismatchFixture.storeURL
        )
        var didExerciseRealOnDiskProtectionMismatch = false
        let onDiskMismatchExporter = makeExporter(
            fixture: onDiskMismatchFixture,
            settings: { [:] },
            protectionClassProvider: { url, fileManager in
                if url.lastPathComponent.hasSuffix(
                    ".sorarecovery.zip"
                ) {
                    didExerciseRealOnDiskProtectionMismatch = true
                    try FileProtectionMetadata.setProtectionClass(
                        .none,
                        at: url,
                        fileManager: fileManager
                    )
                }
                return try FileProtectionMetadata.protectionClass(
                    at: url,
                    fileManager: fileManager
                )
            }
        )

        XCTAssertThrowsError(
            try onDiskMismatchExporter.createRecoveryPackage()
        ) { error in
            guard
                case WalletRecoveryExportError.publicationFailed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(didExerciseRealOnDiskProtectionMismatch)
        XCTAssertTrue(
            try publishedPackages(in: onDiskMismatchFixture).isEmpty
        )
        XCTAssertTrue(
            try hiddenStagingEntries(in: onDiskMismatchFixture).isEmpty
        )

        let retainedHiddenFixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(
                at: retainedHiddenFixture.root
            )
        }
        try Data("live".utf8).write(
            to: retainedHiddenFixture.storeURL
        )
        var didRejectMismatchedPublishedProtection = false
        let retainedHiddenExporter = makeExporter(
            fixture: retainedHiddenFixture,
            settings: { [:] },
            protectionClassProvider: { url, fileManager in
                if url.lastPathComponent.hasSuffix(
                    ".sorarecovery.zip"
                ) {
                    didRejectMismatchedPublishedProtection = true
                    return FileProtectionType.none
                }
                return try FileProtectionMetadata.protectionClass(
                    at: url,
                    fileManager: fileManager
                )
            },
            removeItem: { url in
                if url.lastPathComponent.hasSuffix(
                    ".archive-staging"
                ) {
                    throw WalletRecoveryExportError
                        .publicationFailed
                }
                try FileManager.default.removeItem(at: url)
            }
        )

        XCTAssertThrowsError(
            try retainedHiddenExporter.createRecoveryPackage()
        ) { error in
            guard
                case WalletRecoveryExportError.publicationFailed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertTrue(didRejectMismatchedPublishedProtection)
        XCTAssertTrue(
            try publishedPackages(in: retainedHiddenFixture).isEmpty
        )
        let retainedHidden = try hiddenStagingEntries(
            in: retainedHiddenFixture
        )
        XCTAssertEqual(retainedHidden.count, 1)
        let retainedArchiveURL = try XCTUnwrap(retainedHidden.first)
        XCTAssertTrue(
            retainedArchiveURL.lastPathComponent.hasSuffix(
                ".archive-staging"
            )
        )
        XCTAssertEqual(
            try FileProtectionMetadata.protectionClass(
                at: retainedArchiveURL,
                fileManager: .default
            ),
            FileProtectionType.complete
        )

        let withdrawalFailureFixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(
                at: withdrawalFailureFixture.root
            )
        }
        try Data("live".utf8).write(
            to: withdrawalFailureFixture.storeURL
        )
        let withdrawalFailureExporter = makeExporter(
            fixture: withdrawalFailureFixture,
            settings: { [:] },
            protectionClassProvider: { url, fileManager in
                guard url.lastPathComponent.hasSuffix(
                    ".sorarecovery.zip"
                ) else {
                    return try FileProtectionMetadata.protectionClass(
                        at: url,
                        fileManager: fileManager
                    )
                }
                let prefix = "SORA-Wallet-Recovery-"
                let suffix = ".sorarecovery.zip"
                let fileName = url.lastPathComponent
                let identifier = String(
                    fileName.dropFirst(prefix.count)
                        .dropLast(suffix.count)
                )
                let collision = url.deletingLastPathComponent()
                    .appendingPathComponent(
                        ".wallet-recovery-\(identifier).archive-staging"
                    )
                try Data("withdrawal-collision".utf8).write(
                    to: collision
                )
                return nil
            }
        )
        XCTAssertThrowsError(
            try withdrawalFailureExporter.createRecoveryPackage()
        ) { error in
            guard
                case WalletRecoveryExportError.publicationWithdrawalFailed = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(
            try publishedPackages(
                in: withdrawalFailureFixture
            ).count,
            1
        )
    }

    func testCleanupFailureLeavesOnlyHiddenUnpublishedStaging()
        throws
    {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try Data("live".utf8).write(to: fixture.storeURL)
        let exporter = makeExporter(
            fixture: fixture,
            settings: { [:] },
            removeItem: { url in
                if url.lastPathComponent.hasSuffix(".staging") {
                    throw WalletRecoveryExportError
                        .publicationFailed
                }
                try FileManager.default.removeItem(at: url)
            }
        )

        XCTAssertThrowsError(try exporter.createRecoveryPackage())
        XCTAssertTrue(try publishedPackages(in: fixture).isEmpty)
        let hidden = try hiddenStagingEntries(in: fixture)
        XCTAssertEqual(hidden.count, 1)
        XCTAssertTrue(
            hidden[0].lastPathComponent.hasSuffix(".staging")
        )
    }

    func testLiveSourceChurnFailsClosedAndLeavesNoPublishedPackage()
        throws
    {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try Data("stable-before-copy".utf8).write(
            to: fixture.storeURL
        )
        var changed = false
        let exporter = makeExporter(
            fixture: fixture,
            settings: { [:] },
            afterInitialSourceVerification: { url in
                guard
                    !changed,
                    url == fixture.storeURL
                else {
                    return
                }
                changed = true
                try Data("changed-during-copy".utf8).write(to: url)
            }
        )

        XCTAssertThrowsError(try exporter.createRecoveryPackage()) {
            guard
                case WalletRecoveryExportError.sourceChanged =
                    $0
            else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
        XCTAssertTrue(changed)
        XCTAssertTrue(try publishedPackages(in: fixture).isEmpty)
        let hidden = try hiddenStagingEntries(in: fixture)
        XCTAssertTrue(
            hidden.allSatisfy {
                $0.lastPathComponent.hasPrefix(
                    ".wallet-recovery-"
                )
            }
        )
    }

    func testSuccessfulExportDoesNotMutateLiveSources() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let main = Data("immutable-live-main".utf8)
        let wal = Data("immutable-live-wal".utf8)
        let walURL = URL(
            fileURLWithPath: fixture.storeURL.path + "-wal"
        )
        try main.write(to: fixture.storeURL)
        try wal.write(to: walURL)
        let settingsSnapshot: [String: Any] = [
            SettingsKey.selectedLocalization.rawValue: "en",
        ]

        _ = try makeExporter(
            fixture: fixture,
            settings: { settingsSnapshot }
        ).createRecoveryPackage()

        XCTAssertEqual(try Data(contentsOf: fixture.storeURL), main)
        XCTAssertEqual(try Data(contentsOf: walURL), wal)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath:
                    "\(fixture.storeURL.path)-shm"
            )
        )
    }

    private struct Fixture {
        let root: URL
        let storeURL: URL
        let cacheURL: URL
    }

    private struct Attempt {
        let attemptID: UUID
        let retainedStoreURL: URL
        let settingsURL: URL
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = root.appendingPathComponent(
            "cache",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: cache,
            withIntermediateDirectories: true
        )
        return Fixture(
            root: root,
            storeURL: root.appendingPathComponent(
                "UserDataModel.sqlite"
            ),
            cacheURL: cache
        )
    }

    private func makeExporter(
        fixture: Fixture,
        settings: @escaping () throws -> [String: Any],
        afterInitialSourceVerification:
            ((URL) throws -> Void)? = nil,
        archiveProvider:
            WalletRecoveryExporter.ArchiveProvider? = nil,
        protectionClassProvider:
            WalletRecoveryExporter.ProtectionClassProvider? = nil,
        removeItem: WalletRecoveryExporter.RemoveItem? = nil
    ) -> WalletRecoveryExporter {
        if let archiveProvider {
            return WalletRecoveryExporter(
                storeURL: fixture.storeURL,
                cacheDirectory: fixture.cacheURL,
                settingsSnapshotProvider: settings,
                now: {
                    Date(timeIntervalSince1970: 1_775_260_800)
                },
                afterInitialSourceVerification:
                    afterInitialSourceVerification,
                archiveProvider: archiveProvider,
                protectionClassProvider: protectionClassProvider,
                removeItem: removeItem
            )
        }
        return WalletRecoveryExporter(
            storeURL: fixture.storeURL,
            cacheDirectory: fixture.cacheURL,
            settingsSnapshotProvider: settings,
            now: {
                Date(timeIntervalSince1970: 1_775_260_800)
            },
            afterInitialSourceVerification:
                afterInitialSourceVerification,
            protectionClassProvider: protectionClassProvider,
            removeItem: removeItem
        )
    }

    private func makeActivatedAttempt(
        fixture: Fixture,
        retainedStore: Data,
        settings: [String: Any],
        updatedAt: String,
        state: String = "activated",
        failureReason: String? = nil,
        includeStagingDecoy: Bool = false
    ) throws -> Attempt {
        let attemptID = UUID()
        let attemptURL = fixture.root
            .appendingPathComponent(
                "WalletMigrationSafety",
                isDirectory: true
            )
            .appendingPathComponent(
                attemptID.uuidString,
                isDirectory: true
            )
        let legacyURL = attemptURL.appendingPathComponent(
            "legacy-store",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: legacyURL,
            withIntermediateDirectories: true
        )

        let accountManifestURL = attemptURL.appendingPathComponent(
            "account-manifest.json"
        )
        try Data("{}".utf8).write(to: accountManifestURL)
        let settingsURL = attemptURL.appendingPathComponent(
            "settings-backup.plist"
        )
        try PropertyListSerialization.data(
            fromPropertyList: settings,
            format: .binary,
            options: 0
        ).write(to: settingsURL)

        let retainedStoreURL = legacyURL.appendingPathComponent(
            fixture.storeURL.lastPathComponent
        )
        try retainedStore.write(to: retainedStoreURL)
        let backupManifestURL = legacyURL.appendingPathComponent(
            "backup-manifest.json"
        )
        try jsonData([
            artifact(
                named: retainedStoreURL.lastPathComponent,
                data: retainedStore
            ),
        ]).write(to: backupManifestURL)

        if includeStagingDecoy {
            let stagingURL = attemptURL.appendingPathComponent(
                "staging",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: stagingURL,
                withIntermediateDirectories: true
            )
            try Data("staging-decoy".utf8).write(
                to: stagingURL.appendingPathComponent(
                    fixture.storeURL.lastPathComponent
                )
            )
        }

        let safetyArtifacts = try [
            ("account-manifest.json", accountManifestURL),
            ("settings-backup.plist", settingsURL),
            ("backup-manifest.json", backupManifestURL),
        ].map {
            artifact(
                named: $0.0,
                data: try Data(contentsOf: $0.1)
            )
        }
        var journal: [String: Any] = [
            "migrationID": attemptID.uuidString,
            "sourceVersion": UserStorageVersion.version1.rawValue,
            "destinationVersion":
                UserStorageVersion.version2.rawValue,
            "state": state,
            "updatedAt": updatedAt,
            "safetyArtifacts": safetyArtifacts,
        ]
        if let failureReason {
            journal["failureReason"] = failureReason
        }
        try jsonData(journal).write(
            to: attemptURL.appendingPathComponent("journal.json")
        )
        return Attempt(
            attemptID: attemptID,
            retainedStoreURL: retainedStoreURL,
            settingsURL: settingsURL
        )
    }

    private func makeUnverifiedStagingAttempt(
        fixture: Fixture,
        stagedStore: Data
    ) throws {
        let attemptID = UUID()
        let attemptURL = fixture.root
            .appendingPathComponent(
                "WalletMigrationSafety",
                isDirectory: true
            )
            .appendingPathComponent(
                attemptID.uuidString,
                isDirectory: true
            )
        let stagingURL = attemptURL.appendingPathComponent(
            "staging",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: stagingURL,
            withIntermediateDirectories: true
        )
        try stagedStore.write(
            to: stagingURL.appendingPathComponent(
                fixture.storeURL.lastPathComponent
            )
        )
        let journal: [String: Any] = [
            "migrationID": attemptID.uuidString,
            "sourceVersion": UserStorageVersion.version1.rawValue,
            "destinationVersion":
                UserStorageVersion.version2.rawValue,
            "state": "inventoryVerified",
            "updatedAt": "2026-08-02T00:00:00Z",
        ]
        try jsonData(journal).write(
            to: attemptURL.appendingPathComponent("journal.json")
        )
    }

    private func publishedPackages(in fixture: Fixture) throws
        -> [URL]
    {
        let directory = fixture.cacheURL.appendingPathComponent(
            "WalletRecoveryExports",
            isDirectory: true
        )
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    }

    private func hiddenStagingEntries(in fixture: Fixture) throws
        -> [URL]
    {
        let directory = fixture.cacheURL.appendingPathComponent(
            "WalletRecoveryExports",
            isDirectory: true
        )
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        ).filter {
            $0.lastPathComponent.hasPrefix(".")
        }
    }

    private func artifact(
        named name: String,
        data: Data
    ) -> [String: Any] {
        [
            "fileName": name,
            "byteCount": data.count,
            "sha256": Data(SHA256.hash(data: data))
                .map { String(format: "%02x", $0) }
                .joined(),
        ]
    }

    private func jsonData(_ value: Any) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: value,
            options: [.sortedKeys]
        )
    }

    private func record(
        _ relativeName: String,
        in manifest: WalletRecoveryExportManifest
    ) throws -> WalletRecoveryExportFileRecord {
        try XCTUnwrap(
            manifest.files.first {
                $0.relativeName == relativeName
            }
        )
    }

    private func assertZIPArchive(_ url: URL) throws {
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".zip"))
        let values = try url.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ]
        )
        XCTAssertEqual(values.isRegularFile, true)
        XCTAssertFalse(values.isSymbolicLink == true)
        XCTAssertTrue(values.fileSize.map { $0 > 4 } == true)
        let publishedProtection = try FileProtectionMetadata.protectionClass(
            at: url,
            fileManager: .default
        )
        #if !targetEnvironment(simulator)
            let attributes = try FileManager.default.attributesOfItem(
                atPath: url.path
            )
            XCTAssertEqual(
                try XCTUnwrap(
                    FileProtectionMetadata.normalized(
                        attributes[.protectionKey]
                    )
                ),
                publishedProtection
            )
        #endif
        XCTAssertEqual(
            publishedProtection,
            FileProtectionType.complete
        )
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let signature = try XCTUnwrap(
            handle.read(upToCount: 4)
        )
        XCTAssertEqual(
            signature,
            Data([0x50, 0x4b, 0x03, 0x04])
        )
        let archive = try Data(contentsOf: url)
        XCTAssertNotNil(
            archive.range(
                of: Data("manifest.json".utf8)
            )
        )
    }

    private func sha256(_ data: Data) -> String {
        Data(SHA256.hash(data: data))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
