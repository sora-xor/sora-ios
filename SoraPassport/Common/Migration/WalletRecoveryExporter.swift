// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import Darwin
import Foundation

enum WalletRecoveryExportSourceType: String, Codable {
    case verifiedMigrationLegacyStore
    case liveStoreFallback
}

struct WalletRecoveryExportFileRecord: Codable, Equatable {
    let relativeName: String
    let byteCount: Int
    let sha256: String
}

struct WalletRecoveryExportManifest: Codable, Equatable {
    let schemaVersion: Int
    let sourceType: WalletRecoveryExportSourceType
    let createdAt: Date
    let files: [WalletRecoveryExportFileRecord]
}

struct WalletRecoveryExportResult {
    let packageURL: URL
    let manifest: WalletRecoveryExportManifest
}

enum WalletRecoveryExportError: LocalizedError {
    case unavailableStore
    case unsafeSource(String)
    case sourceChanged(String)
    case invalidSettings
    case exportTooLarge
    case publicationFailed
    case publicationWithdrawalFailed

    var errorDescription: String? {
        switch self {
        case .unavailableStore:
            return "The preserved wallet database is unavailable."
        case let .unsafeSource(file):
            return "The preserved wallet file \(file) could not be verified."
        case let .sourceChanged(file):
            return "The preserved wallet file \(file) changed while it was being exported. Nothing was published."
        case .invalidSettings:
            return "The protected wallet settings could not be safely exported."
        case .exportTooLarge:
            return "The preserved wallet data exceeds the bounded recovery export size."
        case .publicationFailed:
            return "The protected recovery package could not be published."
        case .publicationWithdrawalFailed:
            return "The recovery package could not be safely withdrawn after publication verification failed."
        }
    }
}

/// Creates a read-only, support-assisted recovery package. It never opens a
/// Core Data store, reads Keychain, clears recovery state, or changes wallet
/// settings. All work happens under hidden cache names until Foundation has
/// produced a complete, bounded ZIP that can be atomically renamed into view.
final class WalletRecoveryExporter {
    typealias VerifiedBackupProvider =
        (URL, FileManager) throws -> WalletRecoveryVerifiedMigrationBackup?
    typealias SettingsSnapshotProvider = () throws -> [String: Any]
    typealias ArchiveProvider =
        (URL, URL, FileManager) throws -> Void
    typealias ProtectionClassProvider =
        (URL, FileManager) throws -> FileProtectionType?
    typealias RemoveItem = (URL) throws -> Void

    private struct SourceFingerprint: Equatable {
        let url: URL
        let fileName: String
        let byteCount: Int
        let sha256: String
    }

    private struct ArchiveIdentity: Equatable {
        let device: dev_t
        let inode: ino_t
    }

    private static let maximumDatabaseFileBytes =
        512 * 1_024 * 1_024
    private static let maximumSettingsBytes = 16 * 1_024 * 1_024
    private static let maximumTotalSourceBytes =
        2 * 1_024 * 1_024 * 1_024
    private static let maximumArchiveBytes =
        maximumTotalSourceBytes + 128 * 1_024 * 1_024
    private static let exportDirectoryName = "WalletRecoveryExports"

    /// Only settings needed to understand or reconstruct public wallet
    /// selection and network preferences are exported. Authentication tokens,
    /// PIN state, invitation data, and every unknown future key are excluded.
    static let recoverableSettingsKeys: Set<String> = [
        UserStorageMigratorKeys.keystoreMigrator,
        UserStorageMigratorKeys.settingsMigrator,
        UserStorageMigratorKeys.selectedAddress,
        UserStorageMigratorKeys.orderedAssetIds,
        SettingsKey.decentralizedId.rawValue,
        SettingsKey.publicKeyId.rawValue,
        SettingsKey.selectedAccount.rawValue,
        SettingsKey.selectedLocalization.rawValue,
        SettingsKey.hasMigrated.rawValue,
        SettingsKey.migratedAccountsV1.rawValue,
        SettingsKey.externalGenesis.rawValue,
        SettingsKey.externalExistentialDeposit.rawValue,
        SettingsKey.externalPrefix.rawValue,
        SettingsKey.assetList.rawValue,
        SettingsKey.walletNetworkStoreVersion.rawValue,
        SettingsKey.tairaEnabled.rawValue,
        SettingsKey.tairaPreferenceWasSet.rawValue,
        SettingsKey.tairaExplicitPreference.rawValue,
        SettingsKey.tairaRemoteDefault.rawValue,
        SettingsKey.nexusEnabled.rawValue,
        SettingsKey.nexusSendsEnabled.rawValue,
        SettingsKey.polkamarktEnabled.rawValue,
        SettingsKey.polkamarktMutationsEnabled.rawValue,
    ]

    private let storeURL: URL
    private let cacheDirectory: URL
    private let fileManager: FileManager
    private let verifiedBackupProvider: VerifiedBackupProvider
    private let settingsSnapshotProvider: SettingsSnapshotProvider
    private let now: () -> Date
    private let makeUUID: () -> UUID
    private let afterInitialSourceVerification: ((URL) throws -> Void)?
    private let archiveProvider: ArchiveProvider
    private let protectionClassProvider: ProtectionClassProvider
    private let removeItem: RemoveItem

    init(
        storeURL: URL = UserStorageParams.storageURL,
        cacheDirectory: URL? = nil,
        fileManager: FileManager = .default,
        verifiedBackupProvider:
            @escaping VerifiedBackupProvider = {
                try WalletRecoveryMigrationJournalProbe
                    .newestVerifiedLegacyStoreBackup(
                        storeURL: $0,
                        fileManager: $1
                    )
            },
        settingsSnapshotProvider:
            @escaping SettingsSnapshotProvider = {
                guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                    throw WalletRecoveryExportError.invalidSettings
                }
                return UserDefaults.standard.persistentDomain(
                    forName: bundleIdentifier
                ) ?? [:]
            },
        now: @escaping () -> Date = Date.init,
        makeUUID: @escaping () -> UUID = UUID.init,
        afterInitialSourceVerification:
            ((URL) throws -> Void)? = nil,
        archiveProvider:
            @escaping ArchiveProvider = {
                try WalletRecoveryExporter
                    .coordinateArchiveForUploading(
                        packageURL: $0,
                        archiveURL: $1,
                        fileManager: $2
                    )
            },
        protectionClassProvider: ProtectionClassProvider? = nil,
        removeItem: RemoveItem? = nil
    ) {
        self.storeURL = storeURL.standardizedFileURL
        self.cacheDirectory = (
            cacheDirectory ??
                fileManager.urls(
                    for: .cachesDirectory,
                    in: .userDomainMask
                ).first ??
                fileManager.temporaryDirectory
        ).standardizedFileURL
        self.fileManager = fileManager
        self.verifiedBackupProvider = verifiedBackupProvider
        self.settingsSnapshotProvider = settingsSnapshotProvider
        self.now = now
        self.makeUUID = makeUUID
        self.afterInitialSourceVerification =
            afterInitialSourceVerification
        self.archiveProvider = archiveProvider
        self.protectionClassProvider = protectionClassProvider ?? {
            try FileProtectionMetadata.protectionClass(
                at: $0,
                fileManager: $1
            )
        }
        self.removeItem = removeItem ?? {
            try fileManager.removeItem(at: $0)
        }
    }

    func createRecoveryPackage() throws -> WalletRecoveryExportResult {
        let source = try makeSourcePlan()
        let exportDirectory = cacheDirectory.appendingPathComponent(
            Self.exportDirectoryName,
            isDirectory: true
        )
        try createProtectedDirectoryIfNeeded(exportDirectory)

        let exportID = makeUUID()
        let stagingURL = exportDirectory.appendingPathComponent(
            ".wallet-recovery-\(exportID.uuidString).staging",
            isDirectory: true
        )
        let archiveStagingURL = exportDirectory.appendingPathComponent(
            ".wallet-recovery-\(exportID.uuidString).archive-staging"
        )
        let finalURL = exportDirectory.appendingPathComponent(
            "SORA-Wallet-Recovery-\(exportID.uuidString).sorarecovery.zip"
        )
        guard
            !fileManager.fileExists(atPath: stagingURL.path),
            !fileManager.fileExists(atPath: archiveStagingURL.path),
            !fileManager.fileExists(atPath: finalURL.path)
        else {
            throw WalletRecoveryExportError.publicationFailed
        }

        var archiveWasPublished = false
        var expectedArchiveIdentity: ArchiveIdentity?
        do {
            try createProtectedDirectory(stagingURL)
            let privatePackageURL = stagingURL.appendingPathComponent(
                "SORA-Wallet-Recovery",
                isDirectory: true
            )
            try createProtectedDirectory(privatePackageURL)
            let walletStoreDirectory = privatePackageURL
                .appendingPathComponent(
                    "wallet-store",
                    isDirectory: true
                )
            try createProtectedDirectory(walletStoreDirectory)

            var fingerprints: [SourceFingerprint] = []
            var records: [WalletRecoveryExportFileRecord] = []
            var totalSourceBytes = 0
            for sourceFile in source.databaseFiles.sorted(by: {
                $0.fileName < $1.fileName
            }) {
                let destination = walletStoreDirectory
                    .appendingPathComponent(sourceFile.fileName)
                let copied = try copyStableSource(
                    sourceFile,
                    to: destination
                )
                fingerprints.append(copied)
                totalSourceBytes = try boundedTotal(
                    totalSourceBytes,
                    adding: copied.byteCount
                )
                records.append(
                    WalletRecoveryExportFileRecord(
                        relativeName:
                            "wallet-store/\(copied.fileName)",
                        byteCount: copied.byteCount,
                        sha256: copied.sha256
                    )
                )
            }

            let settingsData: Data
            var settingsFingerprint: SourceFingerprint?
            switch source.settings {
            case let .verified(file):
                let stable = try readStableSource(
                    file,
                    maximumBytes: Self.maximumSettingsBytes
                )
                settingsFingerprint = stable.fingerprint
                settingsData = try filteredSettingsData(
                    from: stable.data
                )
            case let .live(data):
                settingsData = data
            }
            totalSourceBytes = try boundedTotal(
                totalSourceBytes,
                adding: settingsData.count
            )
            guard
                !settingsData.isEmpty,
                settingsData.count <= Self.maximumSettingsBytes
            else {
                throw WalletRecoveryExportError.invalidSettings
            }
            let settingsURL = privatePackageURL.appendingPathComponent(
                "settings-backup.plist"
            )
            try writeProtected(settingsData, to: settingsURL)
            records.append(
                try outputRecord(
                    for: settingsURL,
                    relativeName: "settings-backup.plist",
                    maximumBytes: Self.maximumSettingsBytes
                )
            )

            let readmeData = Data(Self.readme.utf8)
            let readmeURL = privatePackageURL.appendingPathComponent(
                "README.txt"
            )
            try writeProtected(readmeData, to: readmeURL)
            records.append(
                try outputRecord(
                    for: readmeURL,
                    relativeName: "README.txt",
                    maximumBytes: 64 * 1_024
                )
            )

            let manifest = WalletRecoveryExportManifest(
                schemaVersion: 1,
                sourceType: source.sourceType,
                createdAt: Date(
                    timeIntervalSince1970:
                        floor(now().timeIntervalSince1970)
                ),
                files: records.sorted {
                    $0.relativeName < $1.relativeName
                }
            )
            let manifestURL = privatePackageURL.appendingPathComponent(
                "manifest.json"
            )
            try writeManifest(manifest, to: manifestURL)

            try verifyPrivateStagingRoot(
                stagingURL,
                packageURL: privatePackageURL
            )
            try verifyPackage(
                at: privatePackageURL,
                manifest: manifest
            )
            try archiveProvider(
                privatePackageURL,
                archiveStagingURL,
                fileManager
            )
            try protect(archiveStagingURL)
            let reviewedArchiveProtection = try requireProtectionClass(
                archiveStagingURL,
                expected: .complete
            )
            try verifyArchive(at: archiveStagingURL)
            try revalidateSources(
                fingerprints,
                settingsFingerprint: settingsFingerprint,
                source: source
            )
            guard let reviewedArchiveIdentity = try regularArchiveIdentity(
                at: archiveStagingURL
            ) else {
                throw WalletRecoveryExportError.publicationFailed
            }
            expectedArchiveIdentity = reviewedArchiveIdentity

            // Cleanup is part of the publication transaction. If the private
            // package cannot be removed, do not expose the archive; any
            // residue remains dot-prefixed and unpublished.
            try removeItem(stagingURL)

            // Cleanup can take time and the earlier staging verification is not
            // publication admission. Bracket a final archive read with exact
            // inode and typed-protection checks; the second check is the last
            // throwing operation before the exclusive rename below.
            guard
                try regularArchiveIdentity(at: archiveStagingURL) ==
                    reviewedArchiveIdentity,
                try requireProtectionClass(
                    archiveStagingURL,
                    expected: reviewedArchiveProtection
                ) == reviewedArchiveProtection
            else {
                throw WalletRecoveryExportError.publicationFailed
            }
            try verifyArchive(at: archiveStagingURL)
            guard
                try regularArchiveIdentity(at: archiveStagingURL) ==
                    reviewedArchiveIdentity,
                try requireProtectionClass(
                    archiveStagingURL,
                    expected: reviewedArchiveProtection
                ) == reviewedArchiveProtection
            else {
                throw WalletRecoveryExportError.publicationFailed
            }

            // This exclusive same-directory rename is the only publication
            // step. A concurrent final entry is never overwritten.
            let publicationResult = archiveStagingURL
                .withUnsafeFileSystemRepresentation { stagingPath in
                    finalURL.withUnsafeFileSystemRepresentation {
                        finalPath in
                        guard let stagingPath, let finalPath else {
                            return Int32(-1)
                        }
                        return Darwin.renameatx_np(
                            AT_FDCWD,
                            stagingPath,
                            AT_FDCWD,
                            finalPath,
                            UInt32(RENAME_EXCL)
                        )
                    }
                }
            guard publicationResult == 0 else {
                throw WalletRecoveryExportError.publicationFailed
            }
            archiveWasPublished = true
            guard
                try archiveEntryIdentity(at: archiveStagingURL) == nil,
                try regularArchiveIdentity(at: finalURL) ==
                    expectedArchiveIdentity
            else {
                throw WalletRecoveryExportError.publicationFailed
            }
            try requireProtectionClass(
                finalURL,
                expected: reviewedArchiveProtection
            )
            try verifyArchive(at: finalURL)
            try DurableFileWriter
                .synchronizeRegularFileAndContainingDirectory(
                    at: finalURL
                )
            guard
                try regularArchiveIdentity(at: finalURL) ==
                    expectedArchiveIdentity
            else {
                throw WalletRecoveryExportError.publicationFailed
            }
            try requireProtectionClass(
                finalURL,
                expected: reviewedArchiveProtection
            )
            try verifyArchive(at: finalURL)
            guard
                try regularArchiveIdentity(at: finalURL) ==
                    reviewedArchiveIdentity,
                try requireProtectionClass(
                    finalURL,
                    expected: reviewedArchiveProtection
                ) == reviewedArchiveProtection
            else {
                throw WalletRecoveryExportError.publicationFailed
            }
            return WalletRecoveryExportResult(
                packageURL: finalURL,
                manifest: manifest
            )
        } catch {
            let publicationError = error
            try? removeItem(stagingURL)
            if archiveWasPublished {
                guard let expectedArchiveIdentity else {
                    throw WalletRecoveryExportError
                        .publicationWithdrawalFailed
                }
                do {
                    try withdrawPublishedArchive(
                        finalURL,
                        to: archiveStagingURL,
                        expectedIdentity: expectedArchiveIdentity
                    )
                } catch {
                    // Never delete or overwrite an unproved final path. A
                    // distinct error tells support that the visible name could
                    // not be atomically withdrawn and needs manual handling.
                    throw WalletRecoveryExportError
                        .publicationWithdrawalFailed
                }
            }
            // Withdrawal has already removed the visible name. Failure to
            // delete the hidden, .complete archive leaves recovery evidence
            // without exposing an ambiguously verified package.
            try? removeItem(archiveStagingURL)
            throw publicationError
        }
    }

    private enum SettingsSource {
        case verified(WalletRecoveryVerifiedSourceFile)
        case live(Data)
    }

    private struct SourcePlan {
        let sourceType: WalletRecoveryExportSourceType
        let databaseFiles: [WalletRecoveryVerifiedSourceFile]
        let settings: SettingsSource
        let liveDatabaseNames: Set<String>?
        let liveSettingsData: Data?
    }

    private func makeSourcePlan() throws -> SourcePlan {
        if let verified = try verifiedBackupProvider(
            storeURL,
            fileManager
        ) {
            try validateDatabaseFileNames(
                verified.databaseFiles.map(\.fileName)
            )
            return SourcePlan(
                sourceType: .verifiedMigrationLegacyStore,
                databaseFiles: verified.databaseFiles,
                settings: .verified(verified.settingsFile),
                liveDatabaseNames: nil,
                liveSettingsData: nil
            )
        }

        // A live fallback is attempted exactly once per explicit export. The
        // store is never opened or checkpointed; all present sidecars must
        // remain stable through the final pre-publication verification.
        let liveFiles = try liveDatabaseFiles()
        let settingsData = try Self.sanitizedSettingsData(
            from: settingsSnapshotProvider()
        )
        return SourcePlan(
            sourceType: .liveStoreFallback,
            databaseFiles: liveFiles,
            settings: .live(settingsData),
            liveDatabaseNames: Set(liveFiles.map(\.fileName)),
            liveSettingsData: settingsData
        )
    }

    private func liveDatabaseFiles()
        throws -> [WalletRecoveryVerifiedSourceFile]
    {
        let parent = storeURL.deletingLastPathComponent()
        let parentValues = try parent.resourceValues(
            forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ]
        )
        guard
            parentValues.isDirectory == true,
            parentValues.isSymbolicLink != true
        else {
            throw WalletRecoveryExportError.unsafeSource(
                storeURL.lastPathComponent
            )
        }

        let urls = ["", "-wal", "-shm"].map {
            URL(fileURLWithPath: storeURL.path + $0)
                .standardizedFileURL
        }
        var files: [WalletRecoveryVerifiedSourceFile] = []
        for url in urls where fileManager.fileExists(atPath: url.path) {
            let fingerprint = try fingerprint(
                url,
                maximumBytes: Self.maximumDatabaseFileBytes,
                allowsEmpty:
                    url.lastPathComponent !=
                        storeURL.lastPathComponent
            )
            files.append(
                WalletRecoveryVerifiedSourceFile(
                    url: url,
                    fileName: fingerprint.fileName,
                    byteCount: fingerprint.byteCount,
                    sha256: fingerprint.sha256
                )
            )
        }
        guard files.contains(where: {
            $0.fileName == storeURL.lastPathComponent
        }) else {
            throw WalletRecoveryExportError.unavailableStore
        }
        try validateDatabaseFileNames(files.map(\.fileName))
        return files
    }

    private func validateDatabaseFileNames(_ names: [String]) throws {
        let databaseName = storeURL.lastPathComponent
        let allowed = Set([
            databaseName,
            "\(databaseName)-wal",
            "\(databaseName)-shm",
        ])
        let actual = Set(names)
        let allFileNamesAreCanonical = names.allSatisfy {
            $0 == ($0 as NSString).lastPathComponent
        }
        guard
            (1 ... 3).contains(names.count),
            names.count == actual.count,
            actual.isSubset(of: allowed),
            actual.contains(databaseName),
            allFileNamesAreCanonical
        else {
            throw WalletRecoveryExportError.unsafeSource(
                databaseName
            )
        }
    }

    private func copyStableSource(
        _ source: WalletRecoveryVerifiedSourceFile,
        to destination: URL
    ) throws -> SourceFingerprint {
        let before = try fingerprint(
            source.url,
            maximumBytes: Self.maximumDatabaseFileBytes,
            allowsEmpty:
                source.fileName != storeURL.lastPathComponent
        )
        guard
            before.fileName == source.fileName,
            before.byteCount == source.byteCount,
            before.sha256 == source.sha256,
            destination.lastPathComponent == source.fileName,
            !fileManager.fileExists(atPath: destination.path)
        else {
            throw WalletRecoveryExportError.unsafeSource(
                source.fileName
            )
        }

        try afterInitialSourceVerification?(source.url)
        try fileManager.copyItem(at: source.url, to: destination)
        try protect(destination)

        let after = try fingerprint(
            source.url,
            maximumBytes: Self.maximumDatabaseFileBytes,
            allowsEmpty:
                source.fileName != storeURL.lastPathComponent
        )
        let retained = try fingerprint(
            destination,
            maximumBytes: Self.maximumDatabaseFileBytes,
            allowsEmpty:
                source.fileName != storeURL.lastPathComponent
        )
        guard before == after else {
            throw WalletRecoveryExportError.sourceChanged(
                source.fileName
            )
        }
        guard
            retained.fileName == before.fileName,
            retained.byteCount == before.byteCount,
            retained.sha256 == before.sha256
        else {
            throw WalletRecoveryExportError.unsafeSource(
                source.fileName
            )
        }
        return before
    }

    private func readStableSource(
        _ source: WalletRecoveryVerifiedSourceFile,
        maximumBytes: Int
    ) throws -> (data: Data, fingerprint: SourceFingerprint) {
        let before = try fingerprint(
            source.url,
            maximumBytes: maximumBytes
        )
        guard
            before.fileName == source.fileName,
            before.byteCount == source.byteCount,
            before.sha256 == source.sha256
        else {
            throw WalletRecoveryExportError.unsafeSource(
                source.fileName
            )
        }
        try afterInitialSourceVerification?(source.url)
        let data = try Data(
            contentsOf: source.url,
            options: [.mappedIfSafe]
        )
        let after = try fingerprint(
            source.url,
            maximumBytes: maximumBytes
        )
        guard
            before == after,
            data.count == before.byteCount,
            sha256(data) == before.sha256
        else {
            throw WalletRecoveryExportError.sourceChanged(
                source.fileName
            )
        }
        return (data, before)
    }

    private func revalidateSources(
        _ fingerprints: [SourceFingerprint],
        settingsFingerprint: SourceFingerprint?,
        source: SourcePlan
    ) throws {
        for expected in fingerprints {
            let current = try fingerprint(
                expected.url,
                maximumBytes: Self.maximumDatabaseFileBytes,
                allowsEmpty:
                    expected.fileName !=
                        storeURL.lastPathComponent
            )
            guard current == expected else {
                throw WalletRecoveryExportError.sourceChanged(
                    expected.fileName
                )
            }
        }
        if let settingsFingerprint {
            let current = try fingerprint(
                settingsFingerprint.url,
                maximumBytes: Self.maximumSettingsBytes
            )
            guard current == settingsFingerprint else {
                throw WalletRecoveryExportError.sourceChanged(
                    settingsFingerprint.fileName
                )
            }
        }
        if let expectedNames = source.liveDatabaseNames {
            let currentNames = Set(
                ["", "-wal", "-shm"].compactMap { suffix in
                    let url = URL(
                        fileURLWithPath: storeURL.path + suffix
                    )
                    return fileManager.fileExists(atPath: url.path)
                        ? url.lastPathComponent
                        : nil
                }
            )
            guard currentNames == expectedNames else {
                throw WalletRecoveryExportError.sourceChanged(
                    storeURL.lastPathComponent
                )
            }
        }
        if let expectedSettings = source.liveSettingsData {
            let currentSettings = try Self.sanitizedSettingsData(
                from: settingsSnapshotProvider()
            )
            guard propertyListsEqual(
                currentSettings,
                expectedSettings
            ) else {
                throw WalletRecoveryExportError.sourceChanged(
                    "settings-backup.plist"
                )
            }
        }
    }

    private func fingerprint(
        _ url: URL,
        maximumBytes: Int,
        allowsEmpty: Bool = false
    ) throws -> SourceFingerprint {
        guard
            url.lastPathComponent ==
                (url.lastPathComponent as NSString).lastPathComponent
        else {
            throw WalletRecoveryExportError.unsafeSource(
                url.lastPathComponent
            )
        }
        let values = try url.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ]
        )
        guard
            values.isRegularFile == true,
            values.isSymbolicLink != true,
            let byteCount = values.fileSize,
            byteCount >= 0,
            allowsEmpty || byteCount > 0,
            byteCount <= maximumBytes
        else {
            throw WalletRecoveryExportError.unsafeSource(
                url.lastPathComponent
            )
        }
        return SourceFingerprint(
            url: url.standardizedFileURL,
            fileName: url.lastPathComponent,
            byteCount: byteCount,
            sha256: try sha256File(
                at: url,
                expectedByteCount: byteCount
            )
        )
    }

    private func filteredSettingsData(
        from data: Data
    ) throws -> Data {
        guard
            data.count > 0,
            data.count <= Self.maximumSettingsBytes,
            let settings = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any]
        else {
            throw WalletRecoveryExportError.invalidSettings
        }
        return try Self.sanitizedSettingsData(from: settings)
    }

    static func sanitizedSettingsData(
        from settings: [String: Any]
    ) throws -> Data {
        let filtered = Dictionary(
            uniqueKeysWithValues: settings
                .filter {
                    Self.recoverableSettingsKeys.contains($0.key)
                }
                .sorted { $0.key < $1.key }
        )
        guard PropertyListSerialization.propertyList(
            filtered,
            isValidFor: .binary
        ) else {
            throw WalletRecoveryExportError.invalidSettings
        }
        let data = try PropertyListSerialization.data(
            fromPropertyList: filtered,
            format: .xml,
            options: 0
        )
        guard
            !data.isEmpty,
            data.count <= Self.maximumSettingsBytes
        else {
            throw WalletRecoveryExportError.invalidSettings
        }
        return data
    }

    private func writeManifest(
        _ manifest: WalletRecoveryExportManifest,
        to url: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        guard !data.isEmpty, data.count <= 256 * 1_024 else {
            throw WalletRecoveryExportError.publicationFailed
        }
        try writeProtected(data, to: url)

        let retained = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard
            retained.count == data.count,
            sha256(retained) == sha256(data),
            try decoder.decode(
                WalletRecoveryExportManifest.self,
                from: retained
            ) == manifest
        else {
            throw WalletRecoveryExportError.publicationFailed
        }
    }

    private func verifyPackage(
        at packageURL: URL,
        manifest: WalletRecoveryExportManifest
    ) throws {
        let relativeNames = manifest.files.map(\.relativeName)
        let nonDatabaseNames = Set(
            relativeNames.filter {
                !$0.hasPrefix("wallet-store/")
            }
        )
        guard
            manifest.schemaVersion == 1,
            (3 ... 5).contains(manifest.files.count),
            Set(relativeNames).count == relativeNames.count,
            nonDatabaseNames == Set([
                "README.txt",
                "settings-backup.plist",
            ])
        else {
            throw WalletRecoveryExportError.publicationFailed
        }

        let topLevel = try fileManager.contentsOfDirectory(
            at: packageURL,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: []
        )
        guard Set(topLevel.map(\.lastPathComponent)) == Set([
            "README.txt",
            "manifest.json",
            "settings-backup.plist",
            "wallet-store",
        ]) else {
            throw WalletRecoveryExportError.publicationFailed
        }
        for entry in topLevel {
            let values = try entry.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ]
            )
            guard values.isSymbolicLink != true else {
                throw WalletRecoveryExportError.publicationFailed
            }
            if entry.lastPathComponent == "wallet-store" {
                guard values.isDirectory == true else {
                    throw WalletRecoveryExportError.publicationFailed
                }
            } else {
                guard values.isRegularFile == true else {
                    throw WalletRecoveryExportError.publicationFailed
                }
            }
        }

        let expectedStoreNames: Set<String> = Set(
            manifest.files.compactMap { record in
                let prefix = "wallet-store/"
                guard record.relativeName.hasPrefix(prefix) else {
                    return nil
                }
                return String(record.relativeName.dropFirst(prefix.count))
            }
        )
        try validateDatabaseFileNames(Array(expectedStoreNames))
        let walletStoreURL = packageURL.appendingPathComponent(
            "wallet-store",
            isDirectory: true
        )
        let retainedStore = try fileManager.contentsOfDirectory(
            at: walletStoreURL,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: []
        )
        guard
            Set(retainedStore.map(\.lastPathComponent)) ==
                expectedStoreNames
        else {
            throw WalletRecoveryExportError.publicationFailed
        }

        for record in manifest.files {
            let components = record.relativeName.split(separator: "/")
            guard
                (components.count == 1 || components.count == 2),
                components.allSatisfy({
                    !$0.isEmpty && $0 != "." && $0 != ".."
                })
            else {
                throw WalletRecoveryExportError.publicationFailed
            }
            let url = components.reduce(packageURL) {
                $0.appendingPathComponent(String($1))
            }
            let retained = try outputRecord(
                for: url,
                relativeName: record.relativeName,
                maximumBytes:
                    record.relativeName.hasPrefix("wallet-store/")
                        ? Self.maximumDatabaseFileBytes
                        : Self.maximumSettingsBytes
            )
            guard retained == record else {
                throw WalletRecoveryExportError.publicationFailed
            }
        }
    }

    private func verifyPrivateStagingRoot(
        _ stagingURL: URL,
        packageURL: URL
    ) throws {
        let entries = try fileManager.contentsOfDirectory(
            at: stagingURL,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ],
            options: []
        )
        guard
            entries.count == 1,
            entries[0].lastPathComponent ==
                packageURL.lastPathComponent
        else {
            throw WalletRecoveryExportError.publicationFailed
        }
        let values = try entries[0].resourceValues(
            forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ]
        )
        guard
            values.isDirectory == true,
            values.isSymbolicLink != true
        else {
            throw WalletRecoveryExportError.publicationFailed
        }
    }

    private func outputRecord(
        for url: URL,
        relativeName: String,
        maximumBytes: Int
    ) throws -> WalletRecoveryExportFileRecord {
        let retained = try fingerprint(
            url,
            maximumBytes: maximumBytes,
            allowsEmpty:
                relativeName.hasPrefix("wallet-store/") &&
                    url.lastPathComponent !=
                        storeURL.lastPathComponent
        )
        return WalletRecoveryExportFileRecord(
            relativeName: relativeName,
            byteCount: retained.byteCount,
            sha256: retained.sha256
        )
    }

    private func boundedTotal(
        _ current: Int,
        adding next: Int
    ) throws -> Int {
        let (total, overflow) = current.addingReportingOverflow(next)
        guard
            !overflow,
            total <= Self.maximumTotalSourceBytes
        else {
            throw WalletRecoveryExportError.exportTooLarge
        }
        return total
    }

    private func createProtectedDirectoryIfNeeded(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            let values = try url.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                ]
            )
            guard
                values.isDirectory == true,
                values.isSymbolicLink != true
            else {
                throw WalletRecoveryExportError.publicationFailed
            }
            try protect(url)
            return
        }
        try createProtectedDirectory(url)
    }

    private func createProtectedDirectory(_ url: URL) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: false,
            attributes: [
                .protectionKey: FileProtectionType.complete,
            ]
        )
        try protect(url)
    }

    private func writeProtected(_ data: Data, to url: URL) throws {
        try data.write(
            to: url,
            options: [.atomic, .completeFileProtection]
        )
        try protect(url)
    }

    private func protect(_ url: URL) throws {
        try FileProtectionMetadata.setProtectionClass(
            .complete,
            at: url,
            fileManager: fileManager
        )
        try requireProtectionClass(url, expected: .complete)
    }

    @discardableResult
    private func requireProtectionClass(
        _ url: URL,
        expected: FileProtectionType
    ) throws -> FileProtectionType {
        let retained: FileProtectionType?
        do {
            retained = try protectionClassProvider(url, fileManager)
        } catch {
            throw WalletRecoveryExportError.publicationFailed
        }
        guard retained == expected else {
            throw WalletRecoveryExportError.publicationFailed
        }
        return expected
    }

    private func regularArchiveIdentity(
        at url: URL
    ) throws -> ArchiveIdentity? {
        var status = stat()
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else {
                return Int32(-1)
            }
            return Darwin.lstat(path, &status)
        }
        guard result == 0 else {
            if errno == ENOENT {
                return nil
            }
            throw WalletRecoveryExportError.publicationFailed
        }
        guard
            (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
        else {
            throw WalletRecoveryExportError.publicationFailed
        }
        return ArchiveIdentity(
            device: status.st_dev,
            inode: status.st_ino
        )
    }

    private func archiveEntryIdentity(
        at url: URL
    ) throws -> ArchiveIdentity? {
        var status = stat()
        let result = url.withUnsafeFileSystemRepresentation { path in
            guard let path else {
                return Int32(-1)
            }
            return Darwin.lstat(path, &status)
        }
        guard result == 0 else {
            if errno == ENOENT {
                return nil
            }
            throw WalletRecoveryExportError.publicationWithdrawalFailed
        }
        return ArchiveIdentity(
            device: status.st_dev,
            inode: status.st_ino
        )
    }

    private func withdrawPublishedArchive(
        _ finalURL: URL,
        to hiddenURL: URL,
        expectedIdentity: ArchiveIdentity
    ) throws {
        guard
            finalURL.deletingLastPathComponent().standardizedFileURL ==
                hiddenURL.deletingLastPathComponent().standardizedFileURL,
            try regularArchiveIdentity(at: finalURL) == expectedIdentity,
            try regularArchiveIdentity(at: hiddenURL) == nil
        else {
            throw WalletRecoveryExportError.publicationWithdrawalFailed
        }
        let renameResult = finalURL.withUnsafeFileSystemRepresentation {
            finalPath in
            hiddenURL.withUnsafeFileSystemRepresentation { hiddenPath in
                guard let finalPath, let hiddenPath else {
                    return Int32(-1)
                }
                return Darwin.renameatx_np(
                    AT_FDCWD,
                    finalPath,
                    AT_FDCWD,
                    hiddenPath,
                    UInt32(RENAME_EXCL)
                )
            }
        }
        guard renameResult == 0 else {
            throw WalletRecoveryExportError.publicationWithdrawalFailed
        }
        let withdrawnIdentity = try archiveEntryIdentity(at: hiddenURL)
        guard withdrawnIdentity == expectedIdentity else {
            if let withdrawnIdentity {
                _ = restoreRejectedArchiveWithdrawal(
                    hiddenURL,
                    to: finalURL,
                    displacedIdentity: withdrawnIdentity
                )
            }
            throw WalletRecoveryExportError.publicationWithdrawalFailed
        }
        guard
            try archiveEntryIdentity(at: finalURL) != expectedIdentity,
            try regularArchiveIdentity(at: hiddenURL) == expectedIdentity
        else {
            throw WalletRecoveryExportError.publicationWithdrawalFailed
        }

        // The final verification may have failed because this exact inode's
        // on-disk protection metadata was removed or weakened. Repair it only
        // after the exclusive rename has made it hidden, then bind every
        // protection and durability check back to the withdrawn identity. If
        // repair cannot be proved, remove only this identity and prove absence;
        // never deliberately retain an unprotected recovery archive.
        do {
            try FileProtectionMetadata.setProtectionClass(
                .complete,
                at: hiddenURL,
                fileManager: fileManager
            )
            guard
                try regularArchiveIdentity(at: hiddenURL) ==
                    expectedIdentity,
                try archiveEntryIdentity(at: finalURL) !=
                    expectedIdentity,
                try FileProtectionMetadata.protectionClass(
                    at: hiddenURL,
                    fileManager: fileManager
                ) == FileProtectionType.complete
            else {
                throw WalletRecoveryExportError
                    .publicationWithdrawalFailed
            }
            try DurableFileWriter
                .synchronizeRegularFileAndContainingDirectory(
                    at: hiddenURL
                )
            guard
                try archiveEntryIdentity(at: finalURL) !=
                    expectedIdentity,
                try regularArchiveIdentity(at: hiddenURL) ==
                    expectedIdentity,
                try FileProtectionMetadata.protectionClass(
                    at: hiddenURL,
                    fileManager: fileManager
                ) == FileProtectionType.complete
            else {
                throw WalletRecoveryExportError
                    .publicationWithdrawalFailed
            }
        } catch {
            do {
                try removeWithdrawnArchiveIfExact(
                    finalURL,
                    hiddenURL: hiddenURL,
                    expectedIdentity: expectedIdentity
                )
            } catch {
                throw WalletRecoveryExportError
                    .publicationWithdrawalFailed
            }
        }
    }

    private func removeWithdrawnArchiveIfExact(
        _ finalURL: URL,
        hiddenURL: URL,
        expectedIdentity: ArchiveIdentity
    ) throws {
        guard
            try archiveEntryIdentity(at: finalURL) != expectedIdentity,
            try regularArchiveIdentity(at: hiddenURL) == expectedIdentity
        else {
            throw WalletRecoveryExportError.publicationWithdrawalFailed
        }
        do {
            try removeItem(hiddenURL)
        } catch {
            // A remover may report an error after completing the unlink. Accept
            // that outcome only when exact absence is independently proved.
        }
        guard
            try archiveEntryIdentity(at: finalURL) != expectedIdentity,
            try archiveEntryIdentity(at: hiddenURL) == nil
        else {
            throw WalletRecoveryExportError.publicationWithdrawalFailed
        }
        try synchronizeArchiveDirectory(
            hiddenURL.deletingLastPathComponent()
        )
        guard
            try archiveEntryIdentity(at: finalURL) != expectedIdentity,
            try archiveEntryIdentity(at: hiddenURL) == nil
        else {
            throw WalletRecoveryExportError.publicationWithdrawalFailed
        }
    }

    private func restoreRejectedArchiveWithdrawal(
        _ hiddenURL: URL,
        to finalURL: URL,
        displacedIdentity: ArchiveIdentity
    ) -> Bool {
        do {
            guard
                try archiveEntryIdentity(at: hiddenURL) ==
                    displacedIdentity,
                try archiveEntryIdentity(at: finalURL) == nil
            else {
                return false
            }
            let renameResult = hiddenURL
                .withUnsafeFileSystemRepresentation { hiddenPath in
                    finalURL.withUnsafeFileSystemRepresentation {
                        finalPath in
                        guard let hiddenPath, let finalPath else {
                            return Int32(-1)
                        }
                        return Darwin.renameatx_np(
                            AT_FDCWD,
                            hiddenPath,
                            AT_FDCWD,
                            finalPath,
                            UInt32(RENAME_EXCL)
                        )
                    }
                }
            guard
                renameResult == 0,
                try archiveEntryIdentity(at: hiddenURL) == nil,
                try archiveEntryIdentity(at: finalURL) ==
                    displacedIdentity
            else {
                return false
            }
            try synchronizeArchiveDirectory(
                finalURL.deletingLastPathComponent()
            )
            let hiddenWasRestored =
                try archiveEntryIdentity(at: hiddenURL) == nil
            let finalWasRestored =
                try archiveEntryIdentity(at: finalURL) ==
                    displacedIdentity
            return hiddenWasRestored && finalWasRestored
        } catch {
            return false
        }
    }

    private func synchronizeArchiveDirectory(_ directoryURL: URL) throws {
        let descriptor = directoryURL.withUnsafeFileSystemRepresentation {
            path in
            guard let path else {
                return Int32(-1)
            }
            return Darwin.open(
                path,
                O_RDONLY | O_NOFOLLOW | O_CLOEXEC
            )
        }
        guard descriptor >= 0 else {
            throw WalletRecoveryExportError.publicationWithdrawalFailed
        }
        defer { _ = Darwin.close(descriptor) }
        var status = stat()
        guard
            Darwin.fstat(descriptor, &status) == 0,
            (status.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR)
        else {
            throw WalletRecoveryExportError.publicationWithdrawalFailed
        }
        while Darwin.fsync(descriptor) != 0 {
            if errno == EINTR {
                continue
            }
            throw WalletRecoveryExportError.publicationWithdrawalFailed
        }
    }

    static func coordinateArchiveForUploading(
        packageURL: URL,
        archiveURL: URL,
        fileManager: FileManager
    ) throws {
        guard !fileManager.fileExists(atPath: archiveURL.path) else {
            throw WalletRecoveryExportError.publicationFailed
        }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var accessorError: Error?
        coordinator.coordinate(
            readingItemAt: packageURL,
            options: .forUploading,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                let values = try coordinatedURL.resourceValues(
                    forKeys: [
                        .fileSizeKey,
                        .isRegularFileKey,
                        .isSymbolicLinkKey,
                    ]
                )
                guard
                    values.isRegularFile == true,
                    values.isSymbolicLink != true,
                    values.fileSize.map({
                        $0 > 0 &&
                            $0 <= Self.maximumArchiveBytes
                    }) == true
                else {
                    throw WalletRecoveryExportError
                        .publicationFailed
                }
                try fileManager.copyItem(
                    at: coordinatedURL,
                    to: archiveURL
                )
                try FileProtectionMetadata.setProtectionClass(
                    .complete,
                    at: archiveURL,
                    fileManager: fileManager
                )
                guard
                    try FileProtectionMetadata.protectionClass(
                        at: archiveURL,
                        fileManager: fileManager
                    ) == FileProtectionType.complete
                else {
                    throw WalletRecoveryExportError
                        .publicationFailed
                }
            } catch {
                accessorError = error
            }
        }
        if let accessorError {
            throw accessorError
        }
        if let coordinationError {
            throw coordinationError
        }
        guard fileManager.fileExists(atPath: archiveURL.path) else {
            throw WalletRecoveryExportError.publicationFailed
        }
    }

    private func verifyArchive(at url: URL) throws {
        let retained = try fingerprint(
            url,
            maximumBytes: Self.maximumArchiveBytes
        )
        guard retained.byteCount > 4 else {
            throw WalletRecoveryExportError.publicationFailed
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let signature = try handle.read(upToCount: 4) ?? Data()
        guard signature == Data([0x50, 0x4b, 0x03, 0x04]) else {
            throw WalletRecoveryExportError.publicationFailed
        }
    }

    private func sha256File(
        at url: URL,
        expectedByteCount: Int
    ) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var consumed = 0
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            guard !data.isEmpty else {
                break
            }
            consumed += data.count
            guard consumed <= expectedByteCount else {
                throw WalletRecoveryExportError.sourceChanged(
                    url.lastPathComponent
                )
            }
            hasher.update(data: data)
        }
        guard consumed == expectedByteCount else {
            throw WalletRecoveryExportError.sourceChanged(
                url.lastPathComponent
            )
        }
        return Data(hasher.finalize())
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func sha256(_ data: Data) -> String {
        Data(SHA256.hash(data: data))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func propertyListsEqual(
        _ lhs: Data,
        _ rhs: Data
    ) -> Bool {
        guard
            let left = try? PropertyListSerialization.propertyList(
                from: lhs,
                options: [],
                format: nil
            ) as? NSDictionary,
            let right = try? PropertyListSerialization.propertyList(
                from: rhs,
                options: [],
                format: nil
            ) as? NSDictionary
        else {
            return false
        }
        return left.isEqual(right)
    }

    private static let readme = """
    SORA WALLET RECOVERY PACKAGE

    This package was created only after you explicitly requested a protected recovery export. It contains a read-only copy of the wallet's public account database and a small allowlist of recovery-relevant settings.

    It does not contain a recovery phrase, mnemonic, seed, private key, Keychain item, PIN, authentication token, or signed transaction payload. Keychain secrets remain only on this device and were not read for this export.

    The database can contain public wallet metadata such as public addresses, account names, asset preferences, and transaction history. Treat this package as private. Share it only through a support channel whose identity you have independently verified.

    Do not delete or reinstall SORA after creating this package. Creating the package does not repair, reset, unlock, or change the installed wallet.
    """
}
