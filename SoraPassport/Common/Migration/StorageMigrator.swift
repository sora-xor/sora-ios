// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import CoreData
import CryptoKit
import Darwin
import Foundation
import SoraKeystore

protocol StorageMigrating {
    func requiresMigration() -> Bool
    func migrate(_ completion: @escaping () -> Void)
}

enum UserStorageMigratorKeys {
    static let keystoreMigrator = "keystoreMigrator"
    static let settingsMigrator = "settingsMigrator"
    static let selectedAddress = "selectedAddress"
    static let orderedAssetIds = "orderedAssetIds"
}

enum UserStorageMigrationError: LocalizedError {
    case unknownStoreVersion
    case unavailableModel(String)
    case incompleteMigrationPath(String, String)
    case interruptedMigration
    case missingWalletStore
    case missingWalletSecret(String)
    case emptyWalletSecret(String)
    case insufficientStorage
    case backupVerificationFailed(String)
    case accountInventoryMismatch
    case selectedAccountMismatch

    var privacySafeOutcomeCode: String {
        switch self {
        case .unknownStoreVersion:
            return "unknown_store_version"
        case .unavailableModel:
            return "unavailable_model"
        case .incompleteMigrationPath:
            return "incomplete_migration_path"
        case .interruptedMigration:
            return "interrupted_migration"
        case .missingWalletStore:
            return "missing_wallet_store"
        case .missingWalletSecret:
            return "missing_wallet_secret"
        case .emptyWalletSecret:
            return "empty_wallet_secret"
        case .insufficientStorage:
            return "insufficient_storage"
        case .backupVerificationFailed:
            return "backup_verification_failed"
        case .accountInventoryMismatch:
            return "account_inventory_mismatch"
        case .selectedAccountMismatch:
            return "selected_account_mismatch"
        }
    }

    static func privacySafeOutcomeCode(for error: Error) -> String {
        (error as? Self)?.privacySafeOutcomeCode ?? "unexpected_failure"
    }

    /// Recovery diagnostics are persisted in UserDefaults and may be included in an
    /// operator-assisted recovery export. Never persist an arbitrary error description here:
    /// migration errors can carry wallet addresses, database paths, or other account identifiers.
    static func privacySafeRecoveryDescription(for error: Error) -> String {
        let outcome = privacySafeOutcomeCode(for: error)
        return "Wallet storage could not be verified safely (\(outcome)). " +
            "Existing wallet data and recovery copies were preserved."
    }

    var errorDescription: String? {
        switch self {
        case .unknownStoreVersion:
            return "The installed wallet database version is unknown."
        case let .unavailableModel(version):
            return "The wallet database model \(version) is unavailable."
        case let .incompleteMigrationPath(source, destination):
            return "There is no complete wallet migration path from \(source) to \(destination)."
        case .interruptedMigration:
            return "A previous wallet database migration was interrupted. The legacy backup and installed wallet data were preserved for recovery."
        case .missingWalletStore:
            return "Existing wallet settings or protected keys were found, but the wallet database is unavailable. No replacement wallet was created."
        case .missingWalletSecret:
            return "A secure wallet key is unavailable."
        case .emptyWalletSecret:
            return "A secure wallet key is empty."
        case .insufficientStorage:
            return "There is not enough protected storage to migrate this wallet without retaining a verified recovery copy."
        case let .backupVerificationFailed(file):
            return "The retained wallet backup could not be verified for \(file)."
        case .accountInventoryMismatch:
            return "Wallet accounts changed while verifying the database migration."
        case .selectedAccountMismatch:
            return "The selected wallet changed while verifying the database migration."
        }
    }
}

private struct UserStorageMigrationAccount: Codable, Equatable {
    let address: String
    let username: String
    let publicKeySHA256: String
    let cryptoType: Int
    let networkType: Int
    let order: Int
    let isSelected: Bool
    let hasSecretKey: Bool
    let hasEntropy: Bool
    let hasSeed: Bool
    let derivationPath: String?

    func replacingSelection(_ isSelected: Bool) -> Self {
        Self(
            address: address,
            username: username,
            publicKeySHA256: publicKeySHA256,
            cryptoType: cryptoType,
            networkType: networkType,
            order: order,
            isSelected: isSelected,
            hasSecretKey: hasSecretKey,
            hasEntropy: hasEntropy,
            hasSeed: hasSeed,
            derivationPath: derivationPath
        )
    }
}

private struct UserStorageMigrationManifest: Codable, Equatable {
    let schemaVersion: Int
    let sourceVersion: String
    let destinationVersion: String
    let accounts: [UserStorageMigrationAccount]
    let selectedAddress: String?
    let settingsSelectedAddress: String?
    let createdAt: Date

    func inventoryEquals(_ other: UserStorageMigrationManifest) -> Bool {
        let lhs = accounts.sorted { $0.address < $1.address }
        let rhs = other.accounts.sorted { $0.address < $1.address }

        guard lhs.count == rhs.count else {
            return false
        }

        // Secret availability is verified before migration and remains in the
        // unchanged Keychain namespace. Core Data migration may legitimately
        // add the selected flag, so compare the identity-bearing fields here
        // and validate selection separately.
        return selectedAddress == other.selectedAddress &&
            settingsSelectedAddress == other.settingsSelectedAddress &&
            zip(lhs, rhs).allSatisfy { source, destination in
                source.address == destination.address &&
                    source.username == destination.username &&
                    source.publicKeySHA256 == destination.publicKeySHA256 &&
                    source.cryptoType == destination.cryptoType &&
                    source.networkType == destination.networkType &&
                    source.order == destination.order &&
                    source.hasSecretKey == destination.hasSecretKey &&
                    source.hasEntropy == destination.hasEntropy &&
                    source.hasSeed == destination.hasSeed &&
                    source.derivationPath == destination.derivationPath
            }
    }
}

private struct UserStorageBackupRecord: Codable, Equatable {
    let fileName: String
    let byteCount: Int
    let sha256: String
}

private struct UserStorageMigrationJournal: Codable {
    enum State: String, Codable {
        case inventoryVerified
        case stagingVerified
        case activated
        case failed
    }

    let migrationID: UUID
    let sourceVersion: String
    let destinationVersion: String
    var state: State
    var updatedAt: Date
    var failureReason: String?
    var safetyArtifacts: [UserStorageBackupRecord]?
    var recoveryMarker: WalletMigrationRecoveryMarker? = nil
}

/// Observes durable migration boundaries for retained-store restart qualification.
/// The observer never authorizes migration or changes its outcome.
enum UserStorageMigrationCheckpoint: String, CaseIterable {
    case preparationCreated, inventoryWritten, backupCopied
    case backupVerified, stagingVerified, liveStoreReplaced, activated
}

final class UserStorageMigrator {
    private static let maximumMigrationAttempts = 16
    private static let maximumJournalBytes = 64 * 1_024
    private static let maximumManifestBytes = 4 * 1_024 * 1_024
    private static let maximumSettingsBackupBytes = 16 * 1_024 * 1_024
    private static let maximumBackupManifestBytes = 64 * 1_024
    private static let maximumAccountsPerManifest = 4_096

    let storeURL: URL
    let modelDirectory: String
    let keystore: KeystoreProtocol
    let settings: SettingsManagerProtocol
    let fileManager: FileManager
    let targetVersion: UserStorageVersion
    private let recoveryGate: WalletRecoveryCapabilityGate
    private let migrationRecoveryMarker: WalletMigrationRecoveryMarker?
    private let checkpoint: ((UserStorageMigrationCheckpoint) throws -> Void)?
    private let availableCapacity: (URL) -> Int64?
    private let loadWalletNetworkSnapshot:
        () throws -> WalletNetworkSnapshot?
    private let afterLegacyStoreCopyBeforeVerification:
        ((URL) throws -> Void)?
    private let beforeSafetyActivationVerification:
        ((URL) throws -> Void)?

    init(
        targetVersion: UserStorageVersion,
        storeURL: URL,
        modelDirectory: String,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        fileManager: FileManager,
        recoveryGate: WalletRecoveryCapabilityGate = .shared,
        migrationRecoveryMarker: WalletMigrationRecoveryMarker? = nil,
        checkpoint: ((UserStorageMigrationCheckpoint) throws -> Void)? = nil,
        availableCapacity: @escaping (URL) -> Int64? = UserStorageMigrator
            .availableCapacityForMigration(at:),
        loadWalletNetworkSnapshot:
            @escaping () throws -> WalletNetworkSnapshot? = {
                try WalletNetworkStore().load()
            },
        afterLegacyStoreCopyBeforeVerification:
            ((URL) throws -> Void)? = nil,
        beforeSafetyActivationVerification:
            ((URL) throws -> Void)? = nil
    ) {
        self.targetVersion = targetVersion
        self.storeURL = storeURL
        self.modelDirectory = modelDirectory
        self.keystore = keystore
        self.settings = settings
        self.fileManager = fileManager
        self.recoveryGate = recoveryGate
        self.migrationRecoveryMarker = migrationRecoveryMarker
        self.checkpoint = checkpoint
        self.availableCapacity = availableCapacity
        self.loadWalletNetworkSnapshot = loadWalletNetworkSnapshot
        self.afterLegacyStoreCopyBeforeVerification =
            afterLegacyStoreCopyBeforeVerification
        self.beforeSafetyActivationVerification =
            beforeSafetyActivationVerification
    }

    /// Startup owns the lifecycle lease while resolving the database journal.
    /// Ordinary mutable access remains blocked until this concrete migrator has
    /// verified activation; this is not a general bypass for wallet operations.
    func migrateAtStartup(
        lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
        hasUnresolvedAccountCommit: @escaping () throws -> Bool = {
            try !WalletAccountCommitJournalStore().unresolved().isEmpty
        }
    ) throws {
        let lease = lifecycleCoordinator.acquire()
        defer { lease.release() }
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        guard !marker.required || marker.isDatabaseInterruption else {
            throw WalletNetworkMigrationError.walletRecoveryRequired
        }
        guard try !hasUnresolvedAccountCommit() else {
            throw UserStorageMigrationError.interruptedMigration
        }
        if marker.required {
            let verificationGate = WalletRecoveryCapabilityGate(
                settings: settings,
                unresolvedMigrationJournal: {
                    WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(
                        storeURL: self.storeURL
                    )
                },
                unresolvedWalletCommitJournal: hasUnresolvedAccountCommit,
                migrationRecoveryMarker: marker
            )
            let verifier = UserStorageMigrator(
                targetVersion: targetVersion, storeURL: storeURL,
                modelDirectory: modelDirectory, keystore: keystore,
                settings: settings, fileManager: fileManager,
                recoveryGate: verificationGate,
                migrationRecoveryMarker: marker,
                checkpoint: checkpoint,
                availableCapacity: availableCapacity,
                loadWalletNetworkSnapshot: loadWalletNetworkSnapshot,
                afterLegacyStoreCopyBeforeVerification:
                    afterLegacyStoreCopyBeforeVerification,
                beforeSafetyActivationVerification:
                    beforeSafetyActivationVerification
            )
            try verifier.performMigration()
            try marker.requireUnchanged(settings)
            guard try !hasUnresolvedAccountCommit() else {
                throw UserStorageMigrationError.interruptedMigration
            }
            try marker.clearAfterVerifiedActivation(settings)
        } else {
            try performMigration()
        }
        try recoveryGate.requireMutableWalletAccess()
    }

    /// Resume a canonical interrupted database attempt while the caller keeps the
    /// exact generic startup marker latched. Account/network proof and marker CAS
    /// remain the outer startup verifier's responsibility.
    func resumeForStartupVerification(marker: WalletMigrationRecoveryMarker) throws {
        try marker.requireUnchangedForStartupVerification(settings)
        guard hasUnresolvedMigrationJournal() else { return }
        let gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false },
            startupVerificationMarker: marker)
        let verifier = UserStorageMigrator(targetVersion: targetVersion, storeURL: storeURL,
            modelDirectory: modelDirectory, keystore: keystore, settings: settings,
            fileManager: fileManager, recoveryGate: gate, migrationRecoveryMarker: marker,
            checkpoint: checkpoint, availableCapacity: availableCapacity,
            loadWalletNetworkSnapshot: loadWalletNetworkSnapshot,
            afterLegacyStoreCopyBeforeVerification: afterLegacyStoreCopyBeforeVerification,
            beforeSafetyActivationVerification: beforeSafetyActivationVerification)
        try verifier.performMigration()
        try marker.requireUnchangedForStartupVerification(settings)
        guard !hasUnresolvedMigrationJournal() else {
            throw UserStorageMigrationError.interruptedMigration
        }
    }

    /// Fresh identity proof for recovery, including stores with an already
    /// verified migration backup. That backup alone does not prove today's keys.
    func verifiedCurrentAccounts() throws -> [AccountItem] {
        try recoveryGate.requireMutableWalletAccess()
        guard pathExistsNoFollow(storeURL), storeBundleIsRegularNoFollow(at: storeURL) else {
            throw UserStorageMigrationError.missingWalletStore
        }
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: storeURL, options: nil)
        guard compatibleVersionForStoreMetadata(metadata) == targetVersion else {
            throw UserStorageMigrationError.unknownStoreVersion
        }
        let model = try createManagedObjectModel(forResource: targetVersion.rawValue)
        let manifest = try createManifest(storeURL: storeURL, model: model,
            sourceVersion: targetVersion, destinationVersion: targetVersion)
        try validateKeychain(for: manifest)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
            configurationName: nil, at: storeURL, options: [
                NSReadOnlyPersistentStoreOption: true,
                NSSQLitePragmasOption: ["query_only": "ON"]
            ])
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        var result: Result<[AccountItem], Error>!
        context.performAndWait {
            result = Result {
                let request = NSFetchRequest<CDAccountItem>(entityName: "CDAccountItem")
                request.returnsObjectsAsFaults = false
                return try context.fetch(request).map { entity in
                    guard let address = entity.identifier,
                          let username = entity.username,
                          let publicKey = entity.publicKey,
                          let cryptoValue = UInt8(exactly: entity.cryptoType),
                          let cryptoType = CryptoType(rawValue: cryptoValue),
                          let networkType = SNAddressType(exactly: entity.networkType),
                          let retained = manifest.accounts.first(where: { $0.address == address }),
                          retained.username == username,
                          retained.publicKeySHA256 == Data(SHA256.hash(data: publicKey)).hexString,
                          retained.cryptoType == Int(entity.cryptoType),
                          retained.networkType == Int(entity.networkType),
                          retained.order == Int(entity.order)
                    else { throw UserStorageMigrationError.accountInventoryMismatch }
                    return AccountItem(address: address, cryptoType: cryptoType,
                        networkType: networkType, username: username, publicKeyData: publicKey,
                        settings: AccountSettings(visibleAssetIds: entity.settings?.visibleAssets as? [String],
                            orderedAssetIds: entity.settings?.orderedAssets as? [String]),
                        order: entity.order, isSelected: entity.isSelected)
                }
            }
        }
        let accounts = try result.get()
        guard accounts.count == manifest.accounts.count,
              Set(accounts.map(\.address)).count == accounts.count,
              try SelectedWalletSettings.resolveSelection(accounts: accounts,
                legacySelectedAddress: manifest.settingsSelectedAddress)?.address == manifest.selectedAddress
        else { throw UserStorageMigrationError.accountInventoryMismatch }
        try recoveryGate.requireMutableWalletAccess()
        return accounts
    }

    func performMigration() throws {
        try recoveryGate.requireAuthorizedLifecycleContinuation()
        // Resume only after independently checking the retained attempt, live
        // inventory and Keychain. The destination schema alone is insufficient.
        if hasUnresolvedMigrationJournal() || migrationRecoveryMarker != nil {
            try resumeInterruptedMigrationIfProven()
        }
        guard !hasUnresolvedMigrationJournal() else {
            throw UserStorageMigrationError.interruptedMigration
        }

        guard pathExistsNoFollow(storeURL) else {
            guard !hasRetainedWalletEvidence() else {
                throw UserStorageMigrationError.missingWalletStore
            }
            return
        }

        // Core Data and SQLite follow symbolic links. Admit the complete live
        // store namespace before asking either framework for metadata: a
        // reachable symlink is still an unsafe wallet store and must never be
        // opened, checkpointed, copied, or migrated through its target.
        guard storeBundleIsRegularNoFollow(at: storeURL) else {
            throw UserStorageMigrationError.unknownStoreVersion
        }

        let maybeMetadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )

        guard
            let metadata = maybeMetadata,
            let sourceVersion = compatibleVersionForStoreMetadata(metadata) else {
            throw UserStorageMigrationError.unknownStoreVersion
        }

        if sourceVersion == targetVersion,
           hasVerifiedSafetyBackup(destinationVersion: targetVersion) {
            return
        }

        // Inventory the installed store through a read-only coordinator before
        // opening it with checkpointing pragmas. In particular, an empty store
        // alongside retained PIN/Keychain evidence must fail closed without
        // changing even the SQLite journal-mode header: that store may be the
        // only recovery evidence left after an interrupted upgrade.
        let sourceModel = try createManagedObjectModel(
            forResource: sourceVersion.rawValue
        )
        let sourceManifest = try createManifest(
            storeURL: storeURL,
            model: sourceModel,
            sourceVersion: sourceVersion,
            destinationVersion: targetVersion
        )
        try validateKeychain(for: sourceManifest)

        // Core Data may create its current empty store while constructing the
        // onboarding dependencies. The read-only manifest has already rejected
        // every retained-wallet marker/key/snapshot. There is no wallet to
        // migrate or back up until onboarding creates the first account.
        if sourceVersion == targetVersion, sourceManifest.accounts.isEmpty {
            return
        }

        try ensureMigrationCapacity()
        try forceWALCheckpointingForStore(at: storeURL)

        let safetyDirectory = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("WalletMigrationSafety", isDirectory: true)
        try fileManager.createDirectory(at: safetyDirectory, withIntermediateDirectories: true)

        let migrationID = UUID()
        let migrationDirectory = safetyDirectory
            .appendingPathComponent(migrationID.uuidString, isDirectory: true)
        let stagingDirectory = migrationDirectory
            .appendingPathComponent("staging", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        try checkpoint?(.preparationCreated)

        let manifestURL = migrationDirectory.appendingPathComponent("account-manifest.json")
        try writeJSON(
            sourceManifest,
            to: manifestURL,
            maximumBytes: Self.maximumManifestBytes
        )
        try backupSettings(to: migrationDirectory.appendingPathComponent("settings-backup.plist"))

        var journal = UserStorageMigrationJournal(
            migrationID: migrationID,
            sourceVersion: sourceVersion.rawValue,
            destinationVersion: targetVersion.rawValue,
            state: .inventoryVerified,
            updatedAt: Date(),
            failureReason: nil,
            safetyArtifacts: nil
        )
        let journalURL = migrationDirectory.appendingPathComponent("journal.json")
        try writeJSON(
            journal,
            to: journalURL,
            maximumBytes: Self.maximumJournalBytes
        )

        try checkpoint?(.inventoryWritten)

        // The immutable backup survives activation and is intentionally not
        // deleted in this release, enabling dual-read/recovery if a later
        // validation discovers an issue.
        let legacyStoreDirectory = migrationDirectory
            .appendingPathComponent("legacy-store", isDirectory: true)
        do {
            try backupStoreBundle(
                at: storeURL,
                to: legacyStoreDirectory
            )
            try checkpoint?(.backupCopied)
            try afterLegacyStoreCopyBeforeVerification?(
                legacyStoreDirectory
            )
            try verifyCopiedLegacyStore(
                in: legacyStoreDirectory,
                sourceModel: sourceModel,
                sourceManifest: sourceManifest,
                sourceVersion: sourceVersion
            )
            journal.safetyArtifacts = try safetyArtifactRecords(
                manifestURL: manifestURL,
                settingsURL: migrationDirectory.appendingPathComponent(
                    "settings-backup.plist"
                ),
                backupManifestURL: legacyStoreDirectory.appendingPathComponent(
                    "backup-manifest.json"
                )
            )
            journal.updatedAt = Date()
            try writeJSON(
                journal,
                to: journalURL,
                maximumBytes: Self.maximumJournalBytes
            )
        } catch {
            recordMigrationFailure(
                error,
                journal: &journal,
                journalURL: journalURL
            )
            throw error
        }

        try checkpoint?(.backupVerified)

        if sourceVersion == targetVersion {
            // Most installed production wallets already use the current Core
            // Data schema. They still require the same immutable,
            // independently verified database/settings snapshot before the
            // new wallet/network namespace may be activated.
            do {
                try beforeSafetyActivationVerification?(
                    migrationDirectory
                )
                guard
                    try verifySafetyAttempt(
                        at: migrationDirectory,
                        journal: journal,
                        expectedState: .inventoryVerified
                    )
                else {
                    throw UserStorageMigrationError
                        .backupVerificationFailed(
                            migrationDirectory.lastPathComponent
                        )
                }
                journal.state = .activated
                journal.updatedAt = Date()
                try writeJSON(
                    journal,
                    to: journalURL,
                    maximumBytes: Self.maximumJournalBytes
                )
            } catch {
                recordMigrationFailure(
                    error,
                    journal: &journal,
                    journalURL: journalURL
                )
                throw error
            }

            try checkpoint?(.activated)

            // Recovery is sticky. This migration began only after the caller
            // observed a clear marker; never erase a marker that another
            // integrity check may have latched while verification was
            // running.
            return
        }

        try migrateAndActivateStore(
            from: sourceVersion, sourceManifest: sourceManifest,
            migrationDirectory: migrationDirectory,
            stagingDirectory: stagingDirectory,
            legacyStoreDirectory: legacyStoreDirectory,
            journal: &journal, journalURL: journalURL
        )
    }

    private func migrateAndActivateStore(
        from sourceVersion: UserStorageVersion,
        sourceManifest: UserStorageMigrationManifest,
        migrationDirectory: URL,
        stagingDirectory: URL,
        legacyStoreDirectory: URL,
        journal: inout UserStorageMigrationJournal,
        journalURL: URL
    ) throws {
        var liveStoreWasReplaced = false
        do {
            let stagedStoreURL = try createMigratedStore(
                from: sourceVersion,
                to: targetVersion,
                storeURL: storeURL,
                stagingDirectoryURL: stagingDirectory,
                selectedAddress: sourceManifest.selectedAddress,
                orderedAssetIds: settings
                    .value(
                        of: [String: Int].self,
                        for: SettingsKey.assetList.rawValue
                    )?
                    .sorted { $0.value < $1.value }
                    .map(\.key)
            )

            let destinationModel = try createManagedObjectModel(forResource: targetVersion.rawValue)
            let stagedManifest = try createManifest(
                storeURL: stagedStoreURL,
                model: destinationModel,
                sourceVersion: sourceVersion,
                destinationVersion: targetVersion
            )

            guard sourceManifest.inventoryEquals(stagedManifest) else {
                throw UserStorageMigrationError.accountInventoryMismatch
            }
            if let selected = sourceManifest.selectedAddress,
               stagedManifest.selectedAddress != selected {
                throw UserStorageMigrationError.selectedAccountMismatch
            }

            journal.state = .stagingVerified
            journal.updatedAt = Date()
            try writeJSON(
                journal,
                to: journalURL,
                maximumBytes: Self.maximumJournalBytes
            )

            try checkpoint?(.stagingVerified)

            // This is the only mutation of the live store and happens after
            // the staging database and secure-key inventory have both passed.
            guard
                storeBundleIsRegularNoFollow(at: storeURL),
                storeBundleIsRegularNoFollow(at: stagedStoreURL)
            else {
                throw UserStorageMigrationError.unknownStoreVersion
            }
            try recoveryGate.requireAuthorizedLifecycleContinuation()
            RetainedMigrationEvidenceHarness.shared
                .recordRollbackStoreBeforeReplacement(storeURL)
            try NSPersistentStoreCoordinator.replaceStore(
                at: storeURL,
                withStoreAt: stagedStoreURL
            )
            liveStoreWasReplaced = true
            try DurableFileWriter
                .synchronizeRegularFileAndContainingDirectory(
                    at: storeURL
                )
            try RetainedMigrationEvidenceHarness.shared
                .injectRollbackAfterLiveStoreReplacement(storeURL)

            try checkpoint?(.liveStoreReplaced)

            let activatedManifest = try createManifest(
                storeURL: storeURL,
                model: destinationModel,
                sourceVersion: sourceVersion,
                destinationVersion: targetVersion
            )
            guard sourceManifest.inventoryEquals(activatedManifest) else {
                throw UserStorageMigrationError.accountInventoryMismatch
            }
            if let selected = sourceManifest.selectedAddress,
               activatedManifest.selectedAddress != selected {
                throw UserStorageMigrationError.selectedAccountMismatch
            }

            try beforeSafetyActivationVerification?(
                migrationDirectory
            )
            guard
                try verifySafetyAttempt(
                    at: migrationDirectory,
                    journal: journal,
                    expectedState: .stagingVerified
                )
            else {
                throw UserStorageMigrationError
                    .backupVerificationFailed(
                        migrationDirectory.lastPathComponent
                    )
            }
            try recoveryGate.requireAuthorizedLifecycleContinuation()
            journal.state = .activated
            journal.updatedAt = Date()
            try writeJSON(
                journal,
                to: journalURL,
                maximumBytes: Self.maximumJournalBytes
            )

            try checkpoint?(.activated)

            // Recovery is sticky. A successful store activation is not
            // authority to clear a marker latched by another integrity check.
        } catch {
            if liveStoreWasReplaced {
                do {
                    let legacyStoreURL = legacyStoreDirectory
                        .appendingPathComponent(storeURL.lastPathComponent)
                    guard storeBundleIsRegularNoFollow(
                        at: legacyStoreURL
                    ) else {
                        throw UserStorageMigrationError
                            .backupVerificationFailed(
                                legacyStoreURL.lastPathComponent
                            )
                    }
                    try NSPersistentStoreCoordinator.replaceStore(
                        at: storeURL,
                        withStoreAt: legacyStoreURL
                    )
                    try DurableFileWriter
                        .synchronizeRegularFileAndContainingDirectory(
                            at: storeURL
                        )
                    RetainedMigrationEvidenceHarness.shared
                        .recordRollbackStoreRestoration(storeURL)
                } catch {
                    Logger.shared.error("Wallet migration outcome: rollback_failed")
                }
            }
            recordMigrationFailure(
                error,
                journal: &journal,
                journalURL: journalURL
            )
            throw error
        }
    }

    /// Finishes only preflight copies. Keeping the attempt and its journal in place makes a
    /// second interruption retryable under the same recovery marker; no live wallet file is replaced.
    private func completeIncompletePreflightAttemptIfProven(at attempt: URL) throws -> Bool {
        let journalURL = attempt.appendingPathComponent("journal.json")
        var journal: UserStorageMigrationJournal?
        if pathExistsNoFollow(journalURL) {
            journal = try readBoundedJSON(UserStorageMigrationJournal.self, at: journalURL,
                                         maximumBytes: Self.maximumJournalBytes)
            if journal?.safetyArtifacts != nil { return false }
        }
        guard let identifier = UUID(uuidString: attempt.lastPathComponent),
              identifier.uuidString == attempt.lastPathComponent,
              storeBundleIsRegularNoFollow(at: storeURL),
              let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let sourceVersion = compatibleVersionForStoreMetadata(metadata)
        else { throw UserStorageMigrationError.interruptedMigration }
        if let journal {
            guard journal.migrationID == identifier,
                  journal.sourceVersion == sourceVersion.rawValue,
                  journal.destinationVersion == targetVersion.rawValue,
                  journal.state == .inventoryVerified, journal.failureReason == nil,
                  journal.updatedAt.timeIntervalSince1970.isFinite,
                  journal.recoveryMarker == nil || journal.recoveryMarker == migrationRecoveryMarker
            else { throw UserStorageMigrationError.interruptedMigration }
        }

        let staging = attempt.appendingPathComponent("staging", isDirectory: true)
        let legacy = attempt.appendingPathComponent("legacy-store", isDirectory: true)
        let manifestURL = attempt.appendingPathComponent("account-manifest.json")
        let settingsURL = attempt.appendingPathComponent("settings-backup.plist")
        let backupManifestURL = legacy.appendingPathComponent("backup-manifest.json")
        let rootNames: Set<String> = ["staging", "legacy-store", "account-manifest.json",
                                     "settings-backup.plist", "journal.json"]
        let root = try incompletePreflightSnapshot(at: attempt, allowedNames: rootNames,
                                                   directories: ["staging", "legacy-store"])
        if pathExistsNoFollow(staging) {
            guard try fileManager.contentsOfDirectory(atPath: staging.path).isEmpty else {
                throw UserStorageMigrationError.interruptedMigration
            }
        }
        // The writer publishes manifest, settings, journal, then legacy copies in this order.
        guard (!pathExistsNoFollow(settingsURL) || pathExistsNoFollow(manifestURL)),
              (journal == nil || pathExistsNoFollow(settingsURL)),
              (!pathExistsNoFollow(legacy) || journal != nil)
        else { throw UserStorageMigrationError.interruptedMigration }

        let model = try createManagedObjectModel(forResource: sourceVersion.rawValue)
        let liveManifest = try createManifest(storeURL: storeURL, model: model,
                                             sourceVersion: sourceVersion, destinationVersion: targetVersion)
        try validateKeychain(for: liveManifest)
        let sourceRecords = try incompletePreflightStoreRecords()
        let sourceNames = Set(sourceRecords.map(\.fileName))
        let legacySnapshot = try pathExistsNoFollow(legacy)
            ? incompletePreflightSnapshot(at: legacy,
                allowedNames: sourceNames.union(["backup-manifest.json"]), directories: []) : nil
        let manifest: UserStorageMigrationManifest
        if pathExistsNoFollow(manifestURL) {
            manifest = try readBoundedJSON(UserStorageMigrationManifest.self, at: manifestURL,
                                          maximumBytes: Self.maximumManifestBytes)
            guard validate(manifest: manifest, sourceVersion: sourceVersion, destinationVersion: targetVersion),
                  manifest.inventoryEquals(liveManifest)
            else { throw UserStorageMigrationError.accountInventoryMismatch }
        } else {
            manifest = liveManifest
        }
        guard let bundle = Bundle.main.bundleIdentifier else {
            throw UserStorageMigrationError.interruptedMigration
        }
        let preferences = UserDefaults.standard.persistentDomain(forName: bundle) ?? [:]
        if pathExistsNoFollow(settingsURL) {
            let data = try readBoundedData(at: settingsURL, maximumBytes: Self.maximumSettingsBackupBytes)
            guard let retained = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                    as? [String: Any],
                  incompletePreflightSettingsEqual(retained, preferences)
            else { throw UserStorageMigrationError.interruptedMigration }
        }
        if pathExistsNoFollow(backupManifestURL) {
            let records = try readBoundedJSON([UserStorageBackupRecord].self, at: backupManifestURL,
                                             maximumBytes: Self.maximumBackupManifestBytes)
            guard records == sourceRecords else { throw UserStorageMigrationError.interruptedMigration }
        }
        for record in sourceRecords {
            let retained = legacy.appendingPathComponent(record.fileName)
            if pathExistsNoFollow(retained) {
                try requireIncompletePreflightPrefix(at: retained,
                    of: storeURL.deletingLastPathComponent().appendingPathComponent(record.fileName))
            }
        }
        try ensureMigrationCapacity()
        try recoveryGate.requireAuthorizedLifecycleContinuation()
        guard try incompletePreflightStoreRecords() == sourceRecords,
              incompletePreflightSettingsEqual(preferences,
                  UserDefaults.standard.persistentDomain(forName: bundle) ?? [:]),
              try incompletePreflightSnapshot(at: attempt, allowedNames: rootNames,
                    directories: ["staging", "legacy-store"]) == root,
              try !pathExistsNoFollow(legacy) || incompletePreflightSnapshot(at: legacy,
                    allowedNames: sourceNames.union(["backup-manifest.json"]), directories: []) == legacySnapshot
        else { throw UserStorageMigrationError.interruptedMigration }

        if !pathExistsNoFollow(staging) {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        }
        if !pathExistsNoFollow(manifestURL) {
            try writeJSON(manifest, to: manifestURL, maximumBytes: Self.maximumManifestBytes)
        }
        if !pathExistsNoFollow(settingsURL) { try backupSettings(to: settingsURL) }
        var completed = journal ?? UserStorageMigrationJournal(
            migrationID: identifier, sourceVersion: sourceVersion.rawValue,
            destinationVersion: targetVersion.rawValue, state: .inventoryVerified,
            updatedAt: Date(), failureReason: nil, safetyArtifacts: nil)
        completed.recoveryMarker = migrationRecoveryMarker
        try writeJSON(completed, to: journalURL, maximumBytes: Self.maximumJournalBytes)
        if !pathExistsNoFollow(legacy) {
            try fileManager.createDirectory(at: legacy, withIntermediateDirectories: false)
        }
        for record in sourceRecords {
            let source = storeURL.deletingLastPathComponent().appendingPathComponent(record.fileName)
            let destination = legacy.appendingPathComponent(record.fileName)
            if pathExistsNoFollow(destination) {
                try requireIncompletePreflightPrefix(at: destination, of: source)
                let size = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize
                if size == record.byteCount { continue }
                // Only a proved redundant partial copy is removed, and the attempt/journal stay
                // present. A restart between removal and recopy sees a missing copy it can rebuild.
                guard try incompletePreflightStoreRecords() == sourceRecords else {
                    throw UserStorageMigrationError.interruptedMigration
                }
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
            try DurableFileWriter.synchronizeRegularFileAndContainingDirectory(at: destination)
            guard try sha256File(at: destination) == record.sha256 else {
                throw UserStorageMigrationError.interruptedMigration
            }
        }
        try writeJSON(sourceRecords, to: backupManifestURL, maximumBytes: Self.maximumBackupManifestBytes)
        try verifyCopiedLegacyStore(in: legacy, sourceModel: model,
                                    sourceManifest: manifest, sourceVersion: sourceVersion)
        try recoveryGate.requireAuthorizedLifecycleContinuation()
        guard try incompletePreflightStoreRecords() == sourceRecords,
              incompletePreflightSettingsEqual(preferences,
                  UserDefaults.standard.persistentDomain(forName: bundle) ?? [:])
        else { throw UserStorageMigrationError.interruptedMigration }
        completed.safetyArtifacts = try safetyArtifactRecords(manifestURL: manifestURL,
            settingsURL: settingsURL, backupManifestURL: backupManifestURL)
        completed.updatedAt = Date()
        try writeJSON(completed, to: journalURL, maximumBytes: Self.maximumJournalBytes)
        return true
    }

    private func incompletePreflightSettingsEqual(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
        // A restart may have latched the exact marker that authorized this retry. Its compare-and-
        // clear is owned by the caller; no other retained preference difference is ignored here.
        let markerKeys = Set([SettingsKey.walletMigrationRecoveryRequired,
            .walletMigrationRecoveryReason, .walletMigrationRecoveryGeneration,
            .walletMigrationRecoveryReasonGeneration, .walletMigrationRecoveryRecord,
            .walletStartupDiagnostic].map(\.rawValue))
        return NSDictionary(dictionary: lhs.filter { !markerKeys.contains($0.key) })
            .isEqual(NSDictionary(dictionary: rhs.filter { !markerKeys.contains($0.key) }))
    }

    private func incompletePreflightStoreRecords() throws -> [UserStorageBackupRecord] {
        guard storeBundleIsRegularNoFollow(at: storeURL) else {
            throw UserStorageMigrationError.interruptedMigration
        }
        return try ["", "-wal", "-shm"].compactMap { suffix in
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            guard pathExistsNoFollow(url) else { return nil }
            let state = try incompletePreflightFileState(at: url, directory: false)
            guard state.size > 0, state.size <= Int.max else {
                throw UserStorageMigrationError.interruptedMigration
            }
            return UserStorageBackupRecord(fileName: url.lastPathComponent,
                                           byteCount: Int(state.size), sha256: try sha256File(at: url))
        }.sorted { $0.fileName < $1.fileName }
    }

    private func incompletePreflightSnapshot(at directory: URL, allowedNames: Set<String>,
                                             directories: Set<String>) throws -> [String: String] {
        var result = ["": try incompletePreflightFileState(at: directory, directory: true).identity]
        let children = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        guard children.count <= allowedNames.count else { throw UserStorageMigrationError.interruptedMigration }
        for child in children {
            guard allowedNames.contains(child.lastPathComponent) else {
                throw UserStorageMigrationError.interruptedMigration
            }
            let isDirectory = directories.contains(child.lastPathComponent)
            let state = try incompletePreflightFileState(at: child, directory: isDirectory)
            result[child.lastPathComponent] = state.identity + (isDirectory ? "" : try sha256File(at: child))
        }
        return result
    }

    private func incompletePreflightFileState(at url: URL, directory: Bool) throws -> (identity: String, size: off_t) {
        var value = stat()
        guard url.withUnsafeFileSystemRepresentation({ path in
            path.map { Darwin.lstat($0, &value) } ?? -1
        }) == 0,
        value.st_mode & mode_t(S_IFMT) == mode_t(directory ? S_IFDIR : S_IFREG),
        directory || value.st_nlink == 1, value.st_size >= 0
        else { throw UserStorageMigrationError.interruptedMigration }
        return ("\(value.st_dev):\(value.st_ino):\(value.st_mode):\(value.st_nlink):\(value.st_size):" +
                "\(value.st_mtimespec.tv_sec):\(value.st_mtimespec.tv_nsec):" +
                "\(value.st_ctimespec.tv_sec):\(value.st_ctimespec.tv_nsec):", value.st_size)
    }

    private func requireIncompletePreflightPrefix(at copy: URL, of source: URL) throws {
        let copiedState = try incompletePreflightFileState(at: copy, directory: false)
        let sourceState = try incompletePreflightFileState(at: source, directory: false)
        guard copiedState.size <= sourceState.size else { throw UserStorageMigrationError.interruptedMigration }
        let copied = try FileHandle(forReadingFrom: copy)
        let original = try FileHandle(forReadingFrom: source)
        defer { try? copied.close(); try? original.close() }
        while let bytes = try copied.read(upToCount: 1_048_576), !bytes.isEmpty {
            var expected = Data()
            while expected.count < bytes.count {
                guard let part = try original.read(upToCount: bytes.count - expected.count), !part.isEmpty else {
                    throw UserStorageMigrationError.interruptedMigration
                }
                expected.append(part)
            }
            guard bytes == expected else { throw UserStorageMigrationError.interruptedMigration }
        }
        guard try incompletePreflightFileState(at: copy, directory: false).identity == copiedState.identity,
              try incompletePreflightFileState(at: source, directory: false).identity == sourceState.identity
        else { throw UserStorageMigrationError.interruptedMigration }
    }

    private func resumeInterruptedMigrationIfProven() throws {
        let attempts = try migrationAttempts(in: migrationSafetyDirectory())
        guard attempts.count <= Self.maximumMigrationAttempts else {
            throw UserStorageMigrationError.interruptedMigration
        }
        var unfinished: [(URL, UserStorageMigrationJournal)] = []
        for attempt in attempts {
            try completeIncompletePreflightAttemptIfProven(at: attempt)
            let journal = try readBoundedJSON(
                UserStorageMigrationJournal.self,
                at: attempt.appendingPathComponent("journal.json"),
                maximumBytes: Self.maximumJournalBytes
            )
            guard journal.migrationID.uuidString == attempt.lastPathComponent,
                  journal.updatedAt.timeIntervalSince1970.isFinite,
                  journal.failureReason == nil || isRecoverableStartupFailure(journal),
                  try verifySafetyAttempt(at: attempt, journal: journal,
                                          expectedState: journal.state,
                                          allowingVerifiedStartupFailure: isRecoverableStartupFailure(journal))
            else {
                throw UserStorageMigrationError.interruptedMigration
            }
            if journal.state != .activated ||
                (migrationRecoveryMarker != nil &&
                 journal.recoveryMarker == migrationRecoveryMarker) {
                unfinished.append((attempt, journal))
            }
        }
        guard unfinished.count == 1 else {
            throw UserStorageMigrationError.interruptedMigration
        }
        let (attempt, retainedJournal) = unfinished[0]
        var journal = retainedJournal
        let failedJournalData = isRecoverableStartupFailure(journal)
            ? try readBoundedData(at: attempt.appendingPathComponent("journal.json"),
                                 maximumBytes: Self.maximumJournalBytes) : nil
        guard journal.state == .inventoryVerified ||
                journal.state == .stagingVerified ||
                isRecoverableStartupFailure(journal) ||
                (journal.state == .activated &&
                 journal.recoveryMarker == migrationRecoveryMarker &&
                 migrationRecoveryMarker != nil),
              journal.recoveryMarker == nil ||
                journal.recoveryMarker == migrationRecoveryMarker,
              let sourceVersion = UserStorageVersion(rawValue: journal.sourceVersion),
              journal.destinationVersion == targetVersion.rawValue,
              storeBundleIsRegularNoFollow(at: storeURL),
              let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let liveVersion = compatibleVersionForStoreMetadata(metadata),
              liveVersion == sourceVersion || liveVersion == targetVersion,
              journal.state != .inventoryVerified || liveVersion == sourceVersion
        else {
            throw UserStorageMigrationError.interruptedMigration
        }
        let manifest = try readBoundedJSON(
            UserStorageMigrationManifest.self,
            at: attempt.appendingPathComponent("account-manifest.json"),
            maximumBytes: Self.maximumManifestBytes
        )
        let backupDirectory = attempt.appendingPathComponent("legacy-store", isDirectory: true)
        try verifyCopiedLegacyStore(
            in: backupDirectory,
            sourceModel: createManagedObjectModel(forResource: sourceVersion.rawValue),
            sourceManifest: manifest, sourceVersion: sourceVersion
        )
        let liveManifest = try createManifest(
            storeURL: storeURL,
            model: createManagedObjectModel(forResource: liveVersion.rawValue),
            sourceVersion: sourceVersion, destinationVersion: targetVersion
        )
        guard manifest.inventoryEquals(liveManifest),
              manifest.selectedAddress == liveManifest.selectedAddress,
              manifest.settingsSelectedAddress == liveManifest.settingsSelectedAddress
        else {
            throw UserStorageMigrationError.accountInventoryMismatch
        }
        try validateKeychain(for: liveManifest)
        try recoveryGate.requireAuthorizedLifecycleContinuation()
        let journalURL = attempt.appendingPathComponent("journal.json")
        if let failedJournalData {
            // Keep the exact original failure record. Only after the retained
            // backup, live inventory and all keys passed may this retry replace
            // the active journal. A restart reuses the same immutable copy.
            try preserveFailedStartupJournal(failedJournalData, at: attempt)
            try recoveryGate.requireAuthorizedLifecycleContinuation()
            guard try readBoundedData(at: journalURL, maximumBytes: Self.maximumJournalBytes) == failedJournalData else {
                throw UserStorageMigrationError.interruptedMigration
            }
            journal.state = liveVersion == sourceVersion ? .inventoryVerified : .stagingVerified
            journal.failureReason = nil
        }
        if let migrationRecoveryMarker {
            // Bind activation to the exact old marker. If the process dies
            // after activation but before compare-and-clear, restart can prove
            // which marker that completed attempt is authorized to resolve.
            journal.recoveryMarker = migrationRecoveryMarker
            try writeJSON(journal, to: journalURL,
                          maximumBytes: Self.maximumJournalBytes)
        }
        if liveVersion == targetVersion {
            try beforeSafetyActivationVerification?(attempt)
            guard try verifySafetyAttempt(at: attempt, journal: journal,
                                          expectedState: journal.state) else {
                throw UserStorageMigrationError.interruptedMigration
            }
            try recoveryGate.requireAuthorizedLifecycleContinuation()
            journal.state = .activated
            journal.updatedAt = Date()
            try writeJSON(journal, to: journalURL,
                          maximumBytes: Self.maximumJournalBytes)
            try checkpoint?(.activated)
            return
        }
        try ensureMigrationCapacity()
        // Preserve unfinished staging files. A new child contains only this
        // restart's candidate; the immutable legacy backup is never replaced.
        let stagingDirectory = attempt.appendingPathComponent("staging", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory,
                                        withIntermediateDirectories: false)
        try migrateAndActivateStore(
            from: sourceVersion, sourceManifest: manifest,
            migrationDirectory: attempt, stagingDirectory: stagingDirectory,
            legacyStoreDirectory: backupDirectory,
            journal: &journal, journalURL: journalURL
        )
    }

    private func isRecoverableStartupFailure(_ journal: UserStorageMigrationJournal) -> Bool {
        migrationRecoveryMarker?.isStartupVerificationFailure == true &&
            journal.state == .failed && journal.failureReason == "unexpected_failure" &&
            journal.safetyArtifacts?.count == 3 &&
            (journal.recoveryMarker == nil || journal.recoveryMarker == migrationRecoveryMarker)
    }

    private func preserveFailedStartupJournal(_ data: Data, at attempt: URL) throws {
        let digest = Data(SHA256.hash(data: data)).hexString
        let retained = attempt.appendingPathComponent("staging", isDirectory: true)
            .appendingPathComponent("recovery-failed-journal-\(digest).json")
        if pathExistsNoFollow(retained) {
            guard try readBoundedData(at: retained, maximumBytes: Self.maximumJournalBytes) == data else {
                throw UserStorageMigrationError.interruptedMigration
            }
        } else {
            try DurableFileWriter.write(data, to: retained, fileManager: fileManager, protection: .complete)
            guard try readBoundedData(at: retained, maximumBytes: Self.maximumJournalBytes) == data else {
                throw UserStorageMigrationError.interruptedMigration
            }
        }
    }

    private func recordMigrationFailure(
        _ error: Error,
        journal: inout UserStorageMigrationJournal,
        journalURL: URL
    ) {
        let outcome = UserStorageMigrationError
            .privacySafeOutcomeCode(for: error)
        journal.state = .failed
        journal.updatedAt = Date()
        journal.failureReason = outcome
        try? writeJSON(
            journal,
            to: journalURL,
            maximumBytes: Self.maximumJournalBytes
        )

        // Never remove or replace the legacy backup on failure.
        settings.setWalletMigrationRecovery(
            reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error),
            preservingExistingReason: true
        )
    }

    private func createMigratedStore(
        from sourceVersion: UserStorageVersion,
        to destinationVersion: UserStorageVersion,
        storeURL: URL,
        stagingDirectoryURL: URL,
        selectedAddress: String?,
        orderedAssetIds: [String]?
    ) throws -> URL {
        var currentVersion = sourceVersion
        var currentURL = storeURL
//don't need them yet, but have to remember where they should be
//        let keystoreMigrator = KeystoreMigrator(
//            sourceVersion: sourceVersion,
//            destinationVersion: destinationVersion,
//            keystore: keystore
//        )
//
//        let settingsMigrator = SettingsMigrator(
//            sourceVersion: sourceVersion,
//            destinationVersion: destinationVersion,
//            settings: settings
//        )

        while currentVersion != destinationVersion {
            guard storeBundleIsRegularNoFollow(at: currentURL) else {
                throw UserStorageMigrationError.unknownStoreVersion
            }
            guard let nextVersion = currentVersion.nextVersion() else {
                throw UserStorageMigrationError.incompleteMigrationPath(
                    sourceVersion.rawValue,
                    destinationVersion.rawValue
                )
            }
            let currentModel = try createManagedObjectModel(forResource: currentVersion.rawValue)
            let nextModel = try createManagedObjectModel(forResource: nextVersion.rawValue)

//            try keystoreMigrator.switchVersion()
//            try settingsMigrator.switchVersion()

            let mapping = try createMapping(from: currentModel, nextModel: nextModel)

            let manager = NSMigrationManager(sourceModel: currentModel, destinationModel: nextModel)

            var userInfo = manager.userInfo ?? [AnyHashable: Any]()
//            userInfo[UserStorageMigratorKeys.keystoreMigrator] = keystoreMigrator
//            userInfo[UserStorageMigratorKeys.settingsMigrator] = settingsMigrator
            userInfo[UserStorageMigratorKeys.selectedAddress] = selectedAddress
            userInfo[UserStorageMigratorKeys.orderedAssetIds] = orderedAssetIds
            manager.userInfo = userInfo

            let nextStepURL = stagingDirectoryURL.appendingPathComponent("\(nextVersion.rawValue).sqlite")

            try manager.migrateStore(
                from: currentURL,
                sourceType: NSSQLiteStoreType,
                options: nil,
                with: mapping,
                toDestinationURL: nextStepURL,
                destinationType: NSSQLiteStoreType,
                destinationOptions: nil
            )

            // Keep prior migration-step stores inside the bounded safety attempt. They are
            // non-authoritative staging artifacts, and retaining them avoids introducing a
            // destructive store primitive into the production wallet migration path. A later
            // release may prune a fully activated attempt only under an independently verified
            // retention policy.

            currentVersion = nextVersion
            currentURL = nextStepURL
        }

        return currentURL
    }

    private func checkIfMigrationNeeded(to version: UserStorageVersion) -> Bool {
        // Force the throwing recovery path even when the live store already
        // advertises the destination model. It may have been atomically
        // replaced immediately before the app was terminated.
        if hasUnresolvedMigrationJournal() {
            return true
        }

        let storageExists = pathExistsNoFollow(storeURL)

        guard storageExists else {
            // Missing Core Data plus any retained selected-account, protected
            // authentication/entropy, or activated network snapshot is an
            // interrupted/lost-storage condition. Force the throwing path so
            // Core Data is never allowed to create a replacement empty store.
            return hasRetainedWalletEvidence()
        }

        guard storeBundleIsRegularNoFollow(at: storeURL) else {
            // Do not let the non-throwing startup probe ask Core Data to
            // resolve a symlinked or otherwise non-regular wallet namespace.
            // Force the throwing recovery path instead.
            return true
        }

        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            // An unreadable installed store is not an empty/new wallet. Force
            // the throwing migration path so startup enters recovery without
            // creating or replacing any wallet state.
            return true
        }

        guard let compatibleVersion = compatibleVersionForStoreMetadata(
            metadata
        ) else {
            return true
        }
        if compatibleVersion != version {
            return true
        }

        // A current-schema database is not yet upgrade-safe merely because no
        // Core Data mapping is required. Require a verified immutable safety
        // snapshot before the separate wallet/network model can be activated.
        return !hasVerifiedSafetyBackup(destinationVersion: version)
    }

    private func hasRetainedWalletEvidence() -> Bool {
        // A retained migration namespace may contain the only verified copy
        // of an installed wallet after the live SQLite file disappears. Even
        // an activated attempt is durable wallet evidence; it must never be
        // mistaken for a pristine install merely because settings, Keychain,
        // and the separately activated network snapshot are also unavailable.
        if pathExistsNoFollow(migrationSafetyDirectory()) {
            return true
        }

        // SQLite can leave authoritative pages in a WAL or rollback journal
        // when the main store is missing. Preserve every such sidecar and
        // route to recovery before Core Data can create a replacement store.
        if !pathExistsNoFollow(storeURL) {
            for suffix in ["-wal", "-shm", "-journal"] {
                if pathExistsNoFollow(
                    URL(fileURLWithPath: storeURL.path + suffix)
                ) {
                    return true
                }
            }
        }

        if settings.hasRetainedWalletSettings() {
            // Raw selected-account and legacy-username key presence is
            // authoritative installation evidence even when a payload no
            // longer decodes. Treating either as absent could route a retained
            // wallet to onboarding.
            return true
        }

        do {
            if try keystore.checkKey(
                for: KeystoreTag.pincode.rawValue
            ) {
                // The PIN tag survives ordinary app upgrades and may also
                // survive a reinstall. It is durable evidence that this is
                // not a pristine wallet namespace, even if Core Data and the
                // selected-account setting are unexpectedly absent.
                return true
            }
        } catch {
            // An unreadable PIN tag is protected installation evidence too.
            return true
        }

        do {
            if try keystore.hasRetainedWalletMaterial() {
                return true
            }
        } catch {
            // An unreadable protected-key inventory is evidence to preserve,
            // never permission to proceed as a clean installation.
            return true
        }

        if settings.hasRetainedWatchOnlyWallet() {
            return true
        }

        do {
            let activeSnapshot = try loadWalletNetworkSnapshot()
            return activeSnapshot?.wallets.isEmpty == false
        } catch {
            // A corrupt or unreadable active snapshot may still be the only
            // surviving account inventory, so it must route to recovery.
            return true
        }
    }

    private func hasUnresolvedMigrationJournal() -> Bool {
        let safetyDirectory = migrationSafetyDirectory()
        guard pathExistsNoFollow(safetyDirectory) else {
            return false
        }

        guard
            let attempts = try? migrationAttempts(
                in: safetyDirectory
            )
        else {
            // An unreadable safety namespace cannot be treated as evidence of
            // a clean migration.
            return true
        }
        guard attempts.count <= Self.maximumMigrationAttempts else {
            // An unexpectedly unbounded recovery namespace is corruption,
            // never evidence that it is safe to open or replace the wallet.
            return true
        }

        for attempt in attempts {
            let journalURL = attempt.appendingPathComponent("journal.json")
            guard
                let journal = try? readBoundedJSON(
                    UserStorageMigrationJournal.self,
                    at: journalURL,
                    maximumBytes: Self.maximumJournalBytes
                ),
                journal.migrationID.uuidString ==
                    attempt.lastPathComponent,
                UserStorageVersion(
                    rawValue: journal.sourceVersion
                ) != nil,
                UserStorageVersion(
                    rawValue: journal.destinationVersion
                ) != nil,
                journal.updatedAt.timeIntervalSince1970.isFinite
            else {
                return true
            }
            // A failed attempt is recovery state, not permission to retry the
            // same live wallet automatically. Only an atomically activated and
            // fully verified journal is safe to ignore on a later launch.
            guard
                journal.state == .activated,
                journal.failureReason == nil,
                (try? verifyActivatedSafetyAttempt(
                    at: attempt,
                    journal: journal
                )) == true
            else {
                return true
            }
        }
        return false
    }

    private func hasVerifiedSafetyBackup(
        destinationVersion: UserStorageVersion
    ) -> Bool {
        let safetyDirectory = migrationSafetyDirectory()
        guard
            pathExistsNoFollow(safetyDirectory),
            let attempts = try? migrationAttempts(
                in: safetyDirectory
            ),
            attempts.count <= Self.maximumMigrationAttempts
        else {
            return false
        }

        for attempt in attempts {
            let journalURL = attempt.appendingPathComponent("journal.json")
            guard
                let journal = try? readBoundedJSON(
                    UserStorageMigrationJournal.self,
                    at: journalURL,
                    maximumBytes: Self.maximumJournalBytes
                ),
                journal.state == .activated,
                journal.failureReason == nil,
                journal.destinationVersion ==
                    destinationVersion.rawValue,
                journal.migrationID.uuidString ==
                    attempt.lastPathComponent,
                (try? verifyActivatedSafetyAttempt(
                    at: attempt,
                    journal: journal
                )) == true
            else {
                continue
            }
            return true
        }
        return false
    }

    private func migrationSafetyDirectory() -> URL {
        storeURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                "WalletMigrationSafety",
                isDirectory: true
            )
    }

    /// `FileManager.fileExists` follows symbolic links and reports a dangling
    /// link as absent. Wallet storage admission needs namespace evidence, not
    /// target reachability, so use `lstat` for the live store, sidecars, and
    /// retained migration directory.
    private func pathExistsNoFollow(_ url: URL) -> Bool {
        var metadata = stat()
        return url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return true }
            if Darwin.lstat(path, &metadata) == 0 {
                return true
            }
            // Only an authoritative ENOENT means absence. Permission, I/O,
            // malformed-path, and every other inspection failure remain
            // protected namespace evidence and therefore force recovery.
            return errno != ENOENT
        }
    }

    /// Requires the SQLite main store to be a regular, non-symlink entry and
    /// every existing sidecar to be regular too. Missing sidecars are valid;
    /// any other `lstat` failure is unsafe rather than evidence of absence.
    private func storeBundleIsRegularNoFollow(at mainStoreURL: URL) -> Bool {
        guard regularFileNoFollow(mainStoreURL, mayBeAbsent: false) else {
            return false
        }
        return ["-wal", "-shm", "-journal"].allSatisfy { suffix in
            regularFileNoFollow(
                URL(fileURLWithPath: mainStoreURL.path + suffix),
                mayBeAbsent: true
            )
        }
    }

    private func regularFileNoFollow(
        _ url: URL,
        mayBeAbsent: Bool
    ) -> Bool {
        var metadata = stat()
        return url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            if Darwin.lstat(path, &metadata) == 0 {
                return
                    (metadata.st_mode & mode_t(S_IFMT)) ==
                    mode_t(S_IFREG)
            }
            return mayBeAbsent && errno == ENOENT
        }
    }

    private func migrationAttempts(
        in safetyDirectory: URL
    ) throws -> [URL] {
        let values = try safetyDirectory.resourceValues(
            forKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ]
        )
        guard
            values.isDirectory == true,
            values.isSymbolicLink != true
        else {
            throw UserStorageMigrationError.interruptedMigration
        }

        let entries = try fileManager.contentsOfDirectory(
            at: safetyDirectory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey,
            ],
            options: []
        )
        var attempts: [URL] = []
        for entry in entries {
            let entryValues = try entry.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey,
                ]
            )
            // This private namespace contains only UUID-named attempt
            // directories. Hidden entries, regular files, symlinks, and
            // malformed directories are all recovery evidence; ignoring one
            // could let migration mutate the live wallet before the
            // process-wide capability gate gets a chance to latch recovery.
            guard
                entryValues.isDirectory == true,
                entryValues.isSymbolicLink != true,
                UUID(uuidString: entry.lastPathComponent) != nil
            else {
                throw UserStorageMigrationError.interruptedMigration
            }
            attempts.append(entry)
        }
        return attempts
    }

    private func verifyActivatedSafetyAttempt(
        at attempt: URL,
        journal: UserStorageMigrationJournal
    ) throws -> Bool {
        try verifySafetyAttempt(
            at: attempt,
            journal: journal,
            expectedState: .activated
        )
    }

    private func verifySafetyAttempt(
        at attempt: URL,
        journal: UserStorageMigrationJournal,
        expectedState: UserStorageMigrationJournal.State,
        allowingVerifiedStartupFailure: Bool = false
    ) throws -> Bool {
        guard
            try WalletMigrationSafetyNamespaceAdmission
                .isExactActivatedAttemptRoot(
                    at: attempt,
                    fileManager: fileManager
                ),
            journal.state == expectedState,
            journal.failureReason == nil ||
                (allowingVerifiedStartupFailure && isRecoverableStartupFailure(journal)),
            let sourceVersion = UserStorageVersion(
                rawValue: journal.sourceVersion
            ),
            let destinationVersion = UserStorageVersion(
                rawValue: journal.destinationVersion
            )
        else {
            return false
        }

        let manifestURL = attempt.appendingPathComponent(
            "account-manifest.json"
        )
        let settingsURL = attempt.appendingPathComponent(
            "settings-backup.plist"
        )
        let legacyStoreDirectory = attempt.appendingPathComponent(
            "legacy-store",
            isDirectory: true
        )
        let backupManifestURL = legacyStoreDirectory
            .appendingPathComponent("backup-manifest.json")

        let expectedArtifacts = try safetyArtifactRecords(
            manifestURL: manifestURL,
            settingsURL: settingsURL,
            backupManifestURL: backupManifestURL
        )
        guard
            journal.safetyArtifacts == expectedArtifacts,
            let manifest = try? readBoundedJSON(
                UserStorageMigrationManifest.self,
                at: manifestURL,
                maximumBytes: Self.maximumManifestBytes
            ),
            validate(
                manifest: manifest,
                sourceVersion: sourceVersion,
                destinationVersion: destinationVersion
            )
        else {
            return false
        }

        let settingsData = try readBoundedData(
            at: settingsURL,
            maximumBytes: Self.maximumSettingsBackupBytes
        )
        guard
            (try? PropertyListSerialization.propertyList(
                from: settingsData,
                options: [],
                format: nil
            )) is [String: Any]
        else {
            return false
        }

        let records = try readBoundedJSON(
            [UserStorageBackupRecord].self,
            at: backupManifestURL,
            maximumBytes: Self.maximumBackupManifestBytes
        )
        return try verifyBackupRecords(
            records,
            in: legacyStoreDirectory
        )
    }

    private func validate(
        manifest: UserStorageMigrationManifest,
        sourceVersion: UserStorageVersion,
        destinationVersion: UserStorageVersion
    ) -> Bool {
        let addresses = manifest.accounts.map(\.address)
        let selected = manifest.accounts.filter(\.isSelected)
        let expectedSelection = selected.first?.address
        let hasValidSelection = manifest.accounts.isEmpty
            ? manifest.selectedAddress == nil
            : selected.count == 1 &&
                manifest.selectedAddress == expectedSelection
        let hasValidSettingsSelection =
            manifest.settingsSelectedAddress == nil ||
            manifest.settingsSelectedAddress.map {
                Set(addresses).contains($0)
            } == true
        return manifest.schemaVersion == 1 &&
            manifest.sourceVersion == sourceVersion.rawValue &&
            manifest.destinationVersion == destinationVersion.rawValue &&
            manifest.createdAt.timeIntervalSince1970.isFinite &&
            manifest.accounts.count <= Self.maximumAccountsPerManifest &&
            Set(addresses).count == addresses.count &&
            manifest.accounts.allSatisfy { account in
                !account.address.isEmpty &&
                    account.address.utf8.count <= 512 &&
                    account.username.utf8.count <= 4_096 &&
                    account.publicKeySHA256.count == 64 &&
                    account.publicKeySHA256.unicodeScalars
                    .allSatisfy {
                        (48 ... 57).contains($0.value) ||
                            (97 ... 102).contains($0.value)
                    } &&
                    UInt8(exactly: account.cryptoType) != nil &&
                    UInt8(exactly: account.networkType) != nil &&
                    (
                        account.derivationPath.map {
                            $0.utf8.count <= 1_024
                        } ?? true
                    )
            } &&
            hasValidSettingsSelection &&
            hasValidSelection
    }

    private func verifyBackupRecords(
        _ records: [UserStorageBackupRecord],
        in directory: URL
    ) throws -> Bool {
        let allowedNames = Set([
            storeURL.lastPathComponent,
            "\(storeURL.lastPathComponent)-wal",
            "\(storeURL.lastPathComponent)-shm",
        ])
        let names = records.map(\.fileName)
        guard
            (1 ... 3).contains(records.count),
            Set(names).count == records.count,
            Set(names).isSubset(of: allowedNames),
            names.contains(storeURL.lastPathComponent)
        else {
            return false
        }

        let entries = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ],
            options: []
        )
        let expectedNames = Set(names).union(["backup-manifest.json"])
        guard
            entries.count == expectedNames.count,
            Set(entries.map(\.lastPathComponent)) == expectedNames
        else {
            return false
        }
        for entry in entries {
            guard try WalletMigrationSafetyNamespaceAdmission
                .isRegularFileNoFollow(at: entry)
            else {
                return false
            }
        }

        for record in records {
            guard
                record.fileName ==
                    (record.fileName as NSString).lastPathComponent,
                record.byteCount > 0,
                record.sha256.count == 64,
                record.sha256.unicodeScalars.allSatisfy({
                    (48 ... 57).contains($0.value) ||
                        (97 ... 102).contains($0.value)
                })
            else {
                return false
            }
            let fileURL = directory.appendingPathComponent(
                record.fileName
            )
            let values = try fileURL.resourceValues(
                forKeys: [
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ]
            )
            guard
                values.isRegularFile == true,
                values.isSymbolicLink != true,
                values.fileSize == record.byteCount,
                try sha256File(at: fileURL) == record.sha256
            else {
                return false
            }
        }
        return true
    }

    private func readBoundedJSON<T: Decodable>(
        _ type: T.Type,
        at url: URL,
        maximumBytes: Int
    ) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            type,
            from: readBoundedData(
                at: url,
                maximumBytes: maximumBytes
            )
        )
    }

    private func readBoundedData(
        at url: URL,
        maximumBytes: Int
    ) throws -> Data {
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
            let fileSize = values.fileSize,
            fileSize > 0,
            fileSize <= maximumBytes
        else {
            throw UserStorageMigrationError.interruptedMigration
        }
        let data = try Data(contentsOf: url)
        guard data.count == fileSize else {
            throw UserStorageMigrationError.interruptedMigration
        }
        return data
    }

    private func compatibleVersionForStoreMetadata(_ metadata: [String: Any]) -> UserStorageVersion? {
        let compatibleVersion = UserStorageVersion.allCases.first {
            guard let model = try? createManagedObjectModel(forResource: $0.rawValue) else {
                return false
            }
            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }

        return compatibleVersion
    }

    private func createManagedObjectModel(forResource resource: String) throws -> NSManagedObjectModel {
        let bundle = Bundle.main
        let omoURL = bundle.url(
            forResource: resource,
            withExtension: "omo",
            subdirectory: modelDirectory
        )

        let momURL = bundle.url(
            forResource: resource,
            withExtension: "mom",
            subdirectory: modelDirectory
        )

        guard
            let modelURL = omoURL ?? momURL,
            let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw UserStorageMigrationError.unavailableModel(resource)
        }

        return model
    }

    private func createMapping(
        from sourceModel: NSManagedObjectModel,
        nextModel: NSManagedObjectModel
    ) throws -> NSMappingModel {
        let maybeCustomMapping = NSMappingModel(
            from: [Bundle.main],
            forSourceModel: sourceModel,
            destinationModel: nextModel
        )

        if let customMapping = maybeCustomMapping {
            return customMapping
        }

        return try NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: nextModel
        )
    }

    private func forceWALCheckpointingForStore(at storeURL: URL) throws {
        guard storeBundleIsRegularNoFollow(at: storeURL) else {
            throw UserStorageMigrationError.unknownStoreVersion
        }
        let maybeMetadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )

        guard
            let metadata = maybeMetadata,
            let currentModel = NSManagedObjectModel.mergedModel(
                from: [Bundle.main],
                forStoreMetadata: metadata
            ) else {
            throw UserStorageMigrationError.unknownStoreVersion
        }

        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)

        let options = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
        let store = try persistentStoreCoordinator.addPersistentStore(at: storeURL, options: options)
        try persistentStoreCoordinator.remove(store)
    }

    private func ensureMigrationCapacity() throws {
        let bundleBytes = try ["", "-wal", "-shm"].reduce(Int64(0)) { total, suffix in
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            guard fileManager.fileExists(atPath: url.path) else {
                return total
            }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let fileSize = values.fileSize, fileSize >= 0 else {
                throw UserStorageMigrationError.insufficientStorage
            }
            let (result, overflow) = total.addingReportingOverflow(Int64(fileSize))
            guard !overflow else {
                throw UserStorageMigrationError.insufficientStorage
            }
            return result
        }

        // Retain the immutable legacy bundle, build a staged destination, and
        // leave headroom for SQLite/Core Data's atomic replacement temporary
        // files. A conservative failure routes to recovery without touching
        // the installed store.
        let (copyBytes, multiplicationOverflow) = bundleBytes.multipliedReportingOverflow(by: 4)
        let (requiredBytes, additionOverflow) = copyBytes.addingReportingOverflow(16 * 1_024 * 1_024)
        guard
            !multiplicationOverflow,
            !additionOverflow,
            let availableBytes = availableCapacity(storeURL.deletingLastPathComponent()),
            availableBytes >= requiredBytes
        else {
            throw UserStorageMigrationError.insufficientStorage
        }
    }

    static func availableCapacityForMigration(at directory: URL) -> Int64? {
        guard let values = try? directory.resourceValues(
            forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ]
        ) else {
            return nil
        }
        if let importantCapacity = values.volumeAvailableCapacityForImportantUsage {
            return importantCapacity
        }
        return values.volumeAvailableCapacity.map(Int64.init)
    }

    private func createManifest(
        storeURL: URL,
        model: NSManagedObjectModel,
        sourceVersion: UserStorageVersion,
        destinationVersion: UserStorageVersion
    ) throws -> UserStorageMigrationManifest {
        guard storeBundleIsRegularNoFollow(at: storeURL) else {
            throw UserStorageMigrationError.unknownStoreVersion
        }
        let settingsSelectedAddress = settings.value(
            of: AccountItem.self,
            for: SettingsKey.selectedAccount.rawValue
        )?.identifier
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let options: [AnyHashable: Any] = [
            NSReadOnlyPersistentStoreOption: true,
            NSSQLitePragmasOption: ["query_only": "ON"]
        ]
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )
        defer { try? coordinator.remove(store) }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        var capturedError: Error?
        var accounts: [UserStorageMigrationAccount] = []
        context.performAndWait {
            do {
                let request = NSFetchRequest<NSManagedObject>(entityName: "CDAccountItem")
                request.returnsObjectsAsFaults = false
                let objects = try context.fetch(request)

                accounts = try objects.map { object in
                    guard
                        let address = object.value(forKey: "identifier") as? String,
                        let publicKey = object.value(forKey: "publicKey") as? Data,
                        !address.isEmpty,
                        !publicKey.isEmpty
                    else {
                        throw UserStorageMigrationError.accountInventoryMismatch
                    }

                    let username = object.value(forKey: "username") as? String ?? ""
                    var secret = try keystore.loadIfKeyExists(
                        KeystoreTag.secretKeyTagForAddress(address)
                    )
                    var entropy = try fetchEntropyForAddress(address)
                    var seed = try keystore.loadIfKeyExists(
                        KeystoreTag.seedTagForAddress(address)
                    )
                    defer {
                        Self.wipeSensitive(&secret)
                        Self.wipeSensitive(&entropy)
                        Self.wipeSensitive(&seed)
                    }
                    let derivation = try keystore.fetchDeriviationForAddress(address)
                    let cryptoRaw =
                        (object.value(forKey: "cryptoType") as? NSNumber)?.intValue ?? 0
                    let networkRaw =
                        (object.value(forKey: "networkType") as? NSNumber)?.intValue ?? 0
                    guard
                        let cryptoValue = UInt8(exactly: cryptoRaw),
                        let cryptoType = CryptoType(rawValue: cryptoValue),
                        let networkType = SNAddressType(exactly: networkRaw)
                    else {
                        throw UserStorageMigrationError.accountInventoryMismatch
                    }
                    let watchOnlyKey = "wallet.watchOnly.\(address)"
                    guard
                        !settings.allKeys().contains(watchOnlyKey) ||
                            settings.anyValue(for: watchOnlyKey) is Bool
                    else {
                        throw UserStorageMigrationError.accountInventoryMismatch
                    }
                    let isExplicitWatchOnly =
                        settings.bool(for: watchOnlyKey) == true
                    guard
                        !isExplicitWatchOnly ||
                            (secret == nil && entropy == nil && seed == nil)
                    else {
                        // A durable watch-only declaration and signing material are
                        // contradictory authority. Never silently promote the account to a
                        // signer or discard either side of the evidence during migration.
                        throw UserStorageMigrationError.accountInventoryMismatch
                    }
                    guard
                        secret != nil ||
                            entropy != nil ||
                            seed != nil ||
                            isExplicitWatchOnly
                    else {
                        throw UserStorageMigrationError.missingWalletSecret(address)
                    }
                    try LegacySoraIdentityValidator.validate(
                        address: address,
                        publicKey: publicKey,
                        cryptoType: cryptoType,
                        networkType: networkType,
                        derivationPath: derivation,
                        entropy: entropy,
                        rawSeed: seed,
                        secret: secret,
                        recoveryGate: recoveryGate
                    )

                    let selectedPropertyExists = object.entity.propertiesByName["isSelected"] != nil
                    let isSelected: Bool
                    if selectedPropertyExists {
                        isSelected = (object.value(forKey: "isSelected") as? NSNumber)?.boolValue ?? false
                    } else {
                        isSelected = settingsSelectedAddress == address
                    }

                    return UserStorageMigrationAccount(
                        address: address,
                        username: username,
                        publicKeySHA256: Data(SHA256.hash(data: publicKey)).hexString,
                        cryptoType: cryptoRaw,
                        networkType: networkRaw,
                        order: Int((object.value(forKey: "order") as? NSNumber)?.intValue ?? 0),
                        isSelected: isSelected,
                        hasSecretKey: secret != nil,
                        hasEntropy: entropy != nil,
                        hasSeed: seed != nil,
                        derivationPath: derivation
                    )
                }
            } catch {
                capturedError = error
            }
        }

        if let capturedError {
            throw capturedError
        }

        let uniqueAddresses = Set(accounts.map(\.address))
        guard uniqueAddresses.count == accounts.count else {
            throw UserStorageMigrationError.accountInventoryMismatch
        }

        var selectedAccounts = accounts.filter(\.isSelected)
        guard selectedAccounts.count <= 1 else {
            throw UserStorageMigrationError.selectedAccountMismatch
        }

        if accounts.isEmpty {
            // A retained selected-account setting with no matching database
            // account is evidence of an unreadable/lost inventory, not a new
            // wallet.
            guard settingsSelectedAddress == nil else {
                throw UserStorageMigrationError.selectedAccountMismatch
            }
            guard !hasRetainedWalletEvidence() else {
                throw UserStorageMigrationError.missingWalletStore
            }
        } else if selectedAccounts.isEmpty {
            // Version 1 stored the selection only in UserDefaults. Later
            // versions store it on CDAccountItem. Keep the legacy setting as a
            // read-only fallback when the database has no authoritative
            // selection, while never allowing a stale/unknown address.
            guard
                let settingsSelectedAddress,
                uniqueAddresses.contains(settingsSelectedAddress),
                accounts.filter({
                    $0.address == settingsSelectedAddress
                }).count == 1
            else {
                throw UserStorageMigrationError.selectedAccountMismatch
            }
            accounts = accounts.map {
                $0.replacingSelection($0.address == settingsSelectedAddress)
            }
            selectedAccounts = accounts.filter(\.isSelected)
        }

        let manifest = UserStorageMigrationManifest(
            schemaVersion: 1,
            sourceVersion: sourceVersion.rawValue,
            destinationVersion: destinationVersion.rawValue,
            accounts: accounts,
            selectedAddress: selectedAccounts.first?.address,
            settingsSelectedAddress: settingsSelectedAddress,
            createdAt: Date()
        )
        guard
            validate(
                manifest: manifest,
                sourceVersion: sourceVersion,
                destinationVersion: destinationVersion
            )
        else {
            throw UserStorageMigrationError.accountInventoryMismatch
        }
        return manifest
    }

    private func validateKeychain(for manifest: UserStorageMigrationManifest) throws {
        for account in manifest.accounts {
            let watchOnlyKey = "wallet.watchOnly.\(account.address)"
            guard
                !settings.allKeys().contains(watchOnlyKey) ||
                    settings.anyValue(for: watchOnlyKey) is Bool
            else {
                throw UserStorageMigrationError.accountInventoryMismatch
            }
            let isExplicitWatchOnly = settings.bool(for: watchOnlyKey) == true
            guard
                !isExplicitWatchOnly ||
                    (!account.hasSecretKey &&
                        !account.hasEntropy &&
                        !account.hasSeed)
            else {
                throw UserStorageMigrationError.accountInventoryMismatch
            }
            guard
                account.hasSecretKey ||
                    account.hasEntropy ||
                    account.hasSeed ||
                    isExplicitWatchOnly
            else {
                throw UserStorageMigrationError.missingWalletSecret(account.address)
            }
            if account.hasSecretKey {
                var secret = try keystore.fetchSecretKeyForAddress(
                    account.address
                )
                defer { Self.wipeSensitive(&secret) }
                guard secret?.isEmpty == false else {
                    throw UserStorageMigrationError.emptyWalletSecret(account.address)
                }
            }
            if account.hasEntropy {
                var entropy = try fetchEntropyForAddress(account.address)
                defer { Self.wipeSensitive(&entropy) }
                guard entropy?.isEmpty == false else {
                    throw UserStorageMigrationError.emptyWalletSecret(account.address)
                }
            }
            if account.hasSeed {
                var seed = try keystore.fetchSeedForAddress(account.address)
                defer { Self.wipeSensitive(&seed) }
                guard seed?.isEmpty == false else {
                    throw UserStorageMigrationError.emptyWalletSecret(account.address)
                }
            }
        }
    }

    private func fetchEntropyForAddress(_ address: String) throws -> Data? {
        if let scoped = try keystore.loadIfKeyExists(
            KeystoreTag.entropyTagForAddress(address)
        ) {
            return scoped
        }
        guard let snapshot = try loadWalletNetworkSnapshot() else {
            return nil
        }
        return try keystore.fetchEntropyForAddress(
            address,
            activeSnapshot: snapshot,
            recoveryGate: recoveryGate
        )
    }

    private func backupStoreBundle(at sourceURL: URL, to directory: URL) throws {
        guard storeBundleIsRegularNoFollow(at: sourceURL) else {
            throw UserStorageMigrationError.backupVerificationFailed(
                sourceURL.lastPathComponent
            )
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var records: [UserStorageBackupRecord] = []
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: sourceURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else {
                continue
            }
            let destination = directory.appendingPathComponent(source.lastPathComponent)
            guard !fileManager.fileExists(atPath: destination.path) else {
                throw UserStorageMigrationError.backupVerificationFailed(
                    destination.lastPathComponent
                )
            }
            let sourceValuesBeforeCopy = try source.resourceValues(
                forKeys: [
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ]
            )
            guard
                sourceValuesBeforeCopy.isRegularFile == true,
                sourceValuesBeforeCopy.isSymbolicLink != true,
                sourceValuesBeforeCopy.fileSize.map({ $0 > 0 }) == true
            else {
                throw UserStorageMigrationError.backupVerificationFailed(
                    source.lastPathComponent
                )
            }
            let sourceHashBeforeCopy = try sha256File(at: source)
            try fileManager.copyItem(at: source, to: destination)
            try DurableFileWriter
                .synchronizeRegularFileAndContainingDirectory(
                    at: destination
                )
            let sourceValues = try source.resourceValues(
                forKeys: [
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ]
            )
            let destinationValues = try destination.resourceValues(
                forKeys: [
                    .fileSizeKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                ]
            )
            let sourceHashAfterCopy = try sha256File(at: source)
            let destinationHash = try sha256File(at: destination)
            guard
                sourceValues.isRegularFile == true,
                sourceValues.isSymbolicLink != true,
                destinationValues.isRegularFile == true,
                destinationValues.isSymbolicLink != true,
                let sourceSize = sourceValues.fileSize,
                sourceSize == destinationValues.fileSize,
                sourceHashBeforeCopy == sourceHashAfterCopy,
                sourceHashAfterCopy == destinationHash
            else {
                throw UserStorageMigrationError.backupVerificationFailed(
                    source.lastPathComponent
                )
            }
            records.append(
                UserStorageBackupRecord(
                    fileName: source.lastPathComponent,
                    byteCount: sourceSize,
                    sha256: destinationHash
                )
            )
        }
        guard records.contains(where: { $0.fileName == sourceURL.lastPathComponent }) else {
            throw UserStorageMigrationError.backupVerificationFailed(
                sourceURL.lastPathComponent
            )
        }
        try writeJSON(
            records.sorted { $0.fileName < $1.fileName },
            to: directory.appendingPathComponent("backup-manifest.json"),
            maximumBytes: Self.maximumBackupManifestBytes
        )
    }

    private func verifyCopiedLegacyStore(
        in directory: URL,
        sourceModel: NSManagedObjectModel,
        sourceManifest: UserStorageMigrationManifest,
        sourceVersion: UserStorageVersion
    ) throws {
        let copiedStoreURL = directory.appendingPathComponent(
            storeURL.lastPathComponent
        )
        let copiedManifest: UserStorageMigrationManifest
        do {
            copiedManifest = try createManifest(
                storeURL: copiedStoreURL,
                model: sourceModel,
                sourceVersion: sourceVersion,
                destinationVersion: targetVersion
            )
        } catch {
            throw UserStorageMigrationError.backupVerificationFailed(
                copiedStoreURL.lastPathComponent
            )
        }
        guard
            sourceManifest.inventoryEquals(copiedManifest),
            sourceManifest.selectedAddress ==
                copiedManifest.selectedAddress,
            sourceManifest.settingsSelectedAddress ==
                copiedManifest.settingsSelectedAddress
        else {
            throw UserStorageMigrationError.backupVerificationFailed(
                copiedStoreURL.lastPathComponent
            )
        }
    }

    private func safetyArtifactRecords(
        manifestURL: URL,
        settingsURL: URL,
        backupManifestURL: URL
    ) throws -> [UserStorageBackupRecord] {
        try [
            ("account-manifest.json", manifestURL),
            ("settings-backup.plist", settingsURL),
            ("backup-manifest.json", backupManifestURL),
        ]
        .map { expectedName, url in
            guard url.lastPathComponent == expectedName else {
                throw UserStorageMigrationError
                    .backupVerificationFailed(expectedName)
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
                byteCount > 0
            else {
                throw UserStorageMigrationError
                    .backupVerificationFailed(expectedName)
            }
            return UserStorageBackupRecord(
                fileName: expectedName,
                byteCount: byteCount,
                sha256: try sha256File(at: url)
            )
        }
        .sorted { $0.fileName < $1.fileName }
    }

    private func sha256File(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            guard !data.isEmpty else {
                break
            }
            hasher.update(data: data)
        }
        return Data(hasher.finalize()).hexString
    }

    private func backupSettings(to url: URL) throws {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            throw UserStorageMigrationError.backupVerificationFailed(
                "settings-backup.plist"
            )
        }
        let preferences =
            UserDefaults.standard.persistentDomain(forName: bundleIdentifier) ?? [:]

        let data = try PropertyListSerialization.data(
            fromPropertyList: preferences,
            format: .binary,
            options: 0
        )
        guard
            !data.isEmpty,
            data.count <= Self.maximumSettingsBackupBytes
        else {
            throw UserStorageMigrationError.backupVerificationFailed(
                url.lastPathComponent
            )
        }
        try DurableFileWriter.write(
            data,
            to: url,
            fileManager: fileManager,
            protection: .complete
        )
        let retained = try readBoundedData(
            at: url,
            maximumBytes: Self.maximumSettingsBackupBytes
        )
        guard
            retained.count == data.count,
            Data(SHA256.hash(data: retained)) == Data(SHA256.hash(data: data))
        else {
            throw UserStorageMigrationError.backupVerificationFailed(
                url.lastPathComponent
            )
        }
    }

    private func writeJSON<T: Encodable>(
        _ value: T,
        to url: URL,
        maximumBytes: Int
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        guard
            !data.isEmpty,
            data.count <= maximumBytes
        else {
            throw UserStorageMigrationError.backupVerificationFailed(
                url.lastPathComponent
            )
        }
        try DurableFileWriter.write(
            data,
            to: url,
            fileManager: fileManager,
            protection: .complete
        )
    }

    private static func wipeSensitive(_ value: inout Data?) {
        if let count = value?.count {
            value?.resetBytes(in: 0 ..< count)
        }
        value = nil
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

extension UserStorageMigrator: StorageMigrating {
    func requiresMigration() -> Bool {
        checkIfMigrationNeeded(to: targetVersion)
    }

    func migrate(_ completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try self?.performMigration()
            } catch {
                self?.settings.setWalletMigrationRecovery(
                    reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
                )
                let outcome = UserStorageMigrationError
                    .privacySafeOutcomeCode(for: error)
                Logger.shared.error(
                    "Wallet migration outcome: \(outcome)"
                )
            }

            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
