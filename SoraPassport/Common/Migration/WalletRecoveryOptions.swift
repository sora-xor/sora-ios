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

import Foundation
import SoraKeystore
import CryptoKit

// MARK: - Availability flags for recovery and welcome-back states

/// Which forward actions a blocking wallet state offers. The Safe Mode screens
/// render the available ones; "Contact support" is always offered.
///
/// Every state has at least one action besides Try again: "Set up this device
/// again" never deletes a Keychain item, so it is always safe to offer.
struct WalletRecoveryOptions: Equatable {
    /// Re-run startup verification (read-only; only a full proof clears it).
    var canRetry = false
    /// Import a recovery phrase as a wallet. Matching Keychain items left on
    /// this iPhone are adopted, never replaced.
    var canRestoreFromPhrase = false
    /// Restore from a Google Drive backup (including backups from App Store
    /// 3.8.6, which have no key verifier).
    var canRestoreFromDrive = false
    /// iOS "Restore existing wallet keys": add the missing keys of an account
    /// that is still in the wallet database, or (welcome back) adopt wallets
    /// whose Keychain items prove their address, after the retained PIN.
    var canRestoreExistingKeys = false
    /// Show recovery phrases whose entropy is on this device, after the PIN.
    var canShowPhraseAfterPin = false
    /// Open the wallet with unprovable accounts read-only. Outside recovery
    /// this is automatic per account; while a marker is set it is not offered.
    var canReadOnly = false
    /// Create a protected recovery export (public data only).
    var canExport = false
    /// iOS "Set up this device again": the wallet database, network model and
    /// wallet settings are set aside (moved, not deleted) and onboarding
    /// starts. Keychain items are never touched.
    var canSetUpDeviceAgain = false
    /// The folder of unfinished-transaction records cannot be read, so every
    /// send would be refused. The records are set aside (moved, not deleted)
    /// on request; accounts, keys and the wallet database are not touched.
    var canSetAsideTransactionRecords = false

    var hasForwardActionBesidesRetry: Bool {
        canRestoreFromPhrase || canRestoreFromDrive || canRestoreExistingKeys ||
            canShowPhraseAfterPin || canReadOnly || canSetUpDeviceAgain ||
            canSetAsideTransactionRecords
    }
}

/// The facts that decide `WalletRecoveryOptions`.
enum WalletRecoveryState: Equatable {
    /// Keychain items from an earlier install and no wallet database: the app
    /// was deleted and installed again, or all accounts were removed in an
    /// older release.
    case welcomeBack(adoptableWallets: Int, walletsWithPhrase: Int, retainedPinUsable: Bool)
    /// A recovery marker is set.
    case recovery(
        retryable: Bool,
        accountsMissingKeys: Int,
        accountsWithPhrase: Int,
        retainedPinUsable: Bool,
        transactionRecordsUnreadable: Bool = false
    )

    var options: WalletRecoveryOptions {
        var options = WalletRecoveryOptions()
        switch self {
        case let .welcomeBack(adoptable, withPhrase, pinUsable):
            options.canRestoreFromPhrase = true
            options.canRestoreFromDrive = true
            options.canRestoreExistingKeys = pinUsable && adoptable > 0
            options.canShowPhraseAfterPin = pinUsable && withPhrase > 0
            options.canSetUpDeviceAgain = true
        case let .recovery(retryable, missing, withPhrase, pinUsable, recordsUnreadable):
            options.canSetAsideTransactionRecords = recordsUnreadable
            options.canRetry = retryable
            options.canRestoreExistingKeys = missing > 0
            // In place for an account that lost its keys; otherwise through
            // "Set up this device again" and onboarding.
            options.canRestoreFromDrive = true
            options.canRestoreFromPhrase = true
            options.canShowPhraseAfterPin = pinUsable && withPhrase > 0
            options.canExport = true
            options.canSetUpDeviceAgain = true
        }
        return options
    }
}

/// Reads the facts for a state from the device. Read-only.
enum WalletRecoveryStateProbe {
    static func welcomeBack(
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol
    ) -> WalletRecoveryState {
        let inventory = (try? RetainedKeychainWalletDiscovery.inventory(keystore: keystore))
            ?? RetainedKeychainWalletDiscovery.Inventory()
        let bound = (try? WalletOwnerPIN.boundAddresses(keystore: keystore)) ?? []
        let owned = inventory.adoptable.filter { bound.contains($0.address) }
        return .welcomeBack(
            adoptableWallets: owned.count,
            walletsWithPhrase: owned.filter(\.hasPhrase).count,
            retainedPinUsable: WalletRetainedPinGate.isUsable(keystore: keystore, settings: settings,
                                                              scope: .welcomeBack)
        )
    }

    /// After a wallet exists: wallets an earlier install left in the
    /// Keychain that are not in the wallet yet, whose own saved PIN binding can restore them. Empty
    /// otherwise. Read-only; call from a background queue.
    static func retainedWalletsAfterSetup(
        keystore: KeystoreProtocol,
        existingAddresses: Set<String>,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) -> [RetainedKeychainWallet] {
        guard WalletRetainedPinGate.hasRetainedPin(keystore: keystore, scope: .afterSetup) else { return [] }
        let bound = (try? WalletOwnerPIN.boundAddresses(keystore: keystore)) ?? []
        return ((try? RetainedKeychainWalletDiscovery.inventory(
            keystore: keystore, excluding: existingAddresses, recoveryGate: recoveryGate
        ).adoptable) ?? []).filter { bound.contains($0.address) }
    }

    static func recovery(
        migrator: UserStorageMigrator,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        pendingTransactionsBaseURL: URL? = nil
    ) -> WalletRecoveryState {
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        let missing = (try? migrator.accountsForCredentialRecovery()) ?? []
        let inventory = (try? migrator.recoveryInventory()) ?? []
        let withPhrase = WalletRecoveryPhraseReveal.availableAddresses(
            accounts: inventory,
            keystore: keystore,
            recoveryGate: WalletRecoveryCapabilityGate(
                settings: settings,
                unresolvedMigrationJournal: { false },
                unresolvedWalletCommitJournal: { false },
                startupVerificationMarker: marker.isRetryableStartupFailure ? marker : nil
            )
        )
        return .recovery(
            retryable: !marker.required || marker.isRetryableStartupFailure || marker.isDatabaseInterruption ||
                marker.isLegacyAccountCommitInterruption,
            accountsMissingKeys: missing.count,
            accountsWithPhrase: withPhrase.count,
            retainedPinUsable: WalletRetainedPinGate.isUsable(keystore: keystore, settings: settings),
            transactionRecordsUnreadable: !PendingTransactionRecords.isReadable(baseURL: pendingTransactionsBaseURL)
        )
    }
}

/// Recovery copies stay on this device. Set and verify the attribute before
/// copying settings or moving any wallet data, including on resumed attempts.
enum WalletPreservedDataProtection {
    static func excludeFromBackup(_ directory: URL) throws {
        let current = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard current.isDirectory == true, current.isSymbolicLink != true else {
            throw CocoaError(.fileWriteUnknown)
        }
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        guard try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

/// Restored defaults and network metadata are not an account database. On a
/// new iPhone they can arrive without any ThisDeviceOnly keys. Keep that
/// metadata locally, then let normal routing choose onboarding or Welcome
/// back from the actual Keychain. SQLite companions and migration/commit
/// journals remain with their existing recovery path: they may contain the
/// only recoverable database and must be resumed before this classification.
enum WalletMissingDatabaseRecovery {
    private enum Failure: Error { case stateChanged }
    @discardableResult
    static func preserveStaleMetadata(
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol,
        paths: WalletLocalStateSetAside.Paths,
        fileManager: FileManager = .default,
        lifecycleCoordinator: WalletLifecycleCoordinator = .shared
    ) throws -> URL? {
        func exists(_ url: URL) -> Bool {
            var info = stat()
            return url.withUnsafeFileSystemRepresentation { $0.map { lstat($0, &info) == 0 } ?? false }
        }
        func isStaleMetadata() throws -> Bool {
            guard !exists(paths.storeURL),
                  !["-wal", "-shm", "-journal"].contains(where: {
                      exists(URL(fileURLWithPath: paths.storeURL.path + $0))
                  }),
                  !exists(paths.storeURL.deletingLastPathComponent()
                    .appendingPathComponent("WalletMigrationSafety")) else { return false }
            // This automatic path may preserve restored defaults, but must
            // never set aside unreadable transfer records without the user's
            // confirmation. Those records keep sending blocked in recovery.
            guard PendingTransactionRecords.isReadable(baseURL: paths.applicationSupportURL) else { return false }
            let sora = paths.applicationSupportURL.appendingPathComponent("SORA")
            let commits = sora.appendingPathComponent("WalletAccountCommits")
            if exists(commits) {
                guard try fileManager.contentsOfDirectory(at: commits, includingPropertiesForKeys: nil).isEmpty else {
                    return false
                }
            }
            // Read the namespace before any move, even though both key states
            // retain the metadata. A locked/erroring Keychain must reach recovery.
            let identifiers = Set(try keystore.allKeyIdentifiers())
            let networks = sora.appendingPathComponent("WalletNetworks")
            let hasNetworkFiles = exists(networks) &&
                ((try? fileManager.contentsOfDirectory(atPath: networks.path).isEmpty) != true)
            // A genuine pre-account-model wallet never had a SQLite store.
            // Its userName is live upgrade input, not restored stale metadata.
            // Preserve it in place for the explicit legacy-upgrade proof; a
            // scoped wallet or any network-model evidence keeps the normal
            // missing-database preservation path.
            if identifiers.contains(KeystoreTag.legacyEntropy.rawValue), !hasNetworkFiles,
               try LegacyWalletUpgradePolicy.isProvenCandidate(keystore: keystore,
                    hasWatchOnlyWallet: settings.hasRetainedWatchOnlyWallet(), snapshot: nil) {
                return false
            }
            return !WalletLocalStateSetAside.walletSettingKeys(in: settings).isEmpty || exists(networks)
        }
        guard try isStaleMetadata() else { return nil }
        do {
            return try WalletLocalStateSetAside.setAside(
                settings: settings, expectedMarker: WalletMigrationRecoveryMarker.capture(settings),
                paths: paths, fileManager: fileManager, lifecycleCoordinator: lifecycleCoordinator,
                preflight: {
                    // An import may have committed while acquisition waited. Never
                    // classify that newly created live database as restored defaults.
                    guard try isStaleMetadata() else { throw Failure.stateChanged }
                })
        } catch Failure.stateChanged { return nil }
    }
}

// MARK: - Set up this device again

/// "Set up this device again": moves this install's wallet database, migration
/// backups, network model and commit journals into
/// `Documents/WalletSetAside/<id>/`, saves a copy of the non-secret wallet
/// settings there, removes those settings and clears the recovery marker.
///
/// - Keychain items (PIN, wallet keys) are never touched. On the next launch
///   the welcome-back screen offers to restore the wallets they prove.
/// - Nothing is deleted. The set-aside folder can be inspected by support.
/// - Only on the user's confirmed request.
enum WalletLocalStateSetAside {
    struct Paths {
        let storeURL: URL
        let applicationSupportURL: URL
        let setAsideRootURL: URL

        static func production(fileManager: FileManager = .default) throws -> Paths {
            let documents = try fileManager.url(
                for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let support = try fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return Paths(
                storeURL: UserStorageParams.storageURL,
                applicationSupportURL: support,
                setAsideRootURL: documents.appendingPathComponent("WalletSetAside", isDirectory: true)
            )
        }
    }

    enum Failure: Error {
        case markerChanged
        /// Some files were moved to `folder` and the others could not be
        /// moved back, or everything was moved and the folder could not be
        /// marked complete. Nothing was deleted and the recovery marker was
        /// left as it was. A retry continues in the same folder.
        case incomplete(folder: URL)
    }

    /// Written into a set-aside folder before the first move, and removed
    /// once the wallet files are moved and the wallet settings removed,
    /// before the recovery marker is cleared. A retry reuses a folder that
    /// has it.
    static let incompleteMarkerName = "INCOMPLETE"

    /// Non-secret UserDefaults keys that describe the installed wallet.
    static func walletSettingKeys(in settings: SettingsManagerProtocol) -> [String] {
        let fixed: Set<String> = [
            SettingsKey.selectedAccount.rawValue,
            SettingsKey.decentralizedId.rawValue,
            SettingsKey.publicKeyId.rawValue,
            SettingsKey.hasMigrated.rawValue,
            SettingsKey.migratedAccountsV1.rawValue,
            SettingsKey.walletNetworkStoreVersion.rawValue,
            SettingsKey.walletStartupDiagnostic.rawValue,
            KeystoreTag.legacyUsername.rawValue,
        ]
        return settings.allKeys().filter { fixed.contains($0) || $0.hasPrefix("wallet.watchOnly.") }.sorted()
    }

    @discardableResult
    static func setAside(
        settings: SettingsManagerProtocol,
        expectedMarker: WalletMigrationRecoveryMarker?,
        paths: Paths,
        fileManager: FileManager = .default,
        lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
        preflight: () throws -> Void = {},
        closeDatabase: () -> Void = {},
        beforeMove: (URL) throws -> Void = { _ in },
        afterMoves: () throws -> Void = {}
    ) throws -> URL {
        let lease = lifecycleCoordinator.acquire()
        defer { lease.release() }
        try preflight()
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        if let expectedMarker, expectedMarker != marker {
            throw Failure.markerChanged
        }
        closeDatabase()

        // Continue an earlier incomplete attempt in its own folder, so the
        // earlier data is never split across folders.
        let reused = incompleteFolder(in: paths.setAsideRootURL, fileManager: fileManager)
        let folder = reused ?? paths.setAsideRootURL.appendingPathComponent(
            "\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: paths.setAsideRootURL, withIntermediateDirectories: true)
        try WalletPreservedDataProtection.excludeFromBackup(paths.setAsideRootURL)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try WalletPreservedDataProtection.excludeFromBackup(folder)

        // 0. Journal the attempt before anything moves. The marker stays
        // until the wallet files are moved and the wallet settings removed
        // (step 4), so a process that dies at any point before that leaves a
        // folder the next attempt finds and continues in. The write is
        // synchronised: a marker that could be lost while the moves survive
        // would split the earlier data across two folders.
        let incompleteMarkerURL = folder.appendingPathComponent(incompleteMarkerName)
        if !exists(incompleteMarkerURL) {
            do {
                try Data("Some wallet files were moved here and others were not. Nothing was deleted.".utf8)
                    .write(to: incompleteMarkerURL, options: [.atomic])
                try DurableFileWriter.synchronizeRegularFileAndContainingDirectory(at: incompleteMarkerURL)
            } catch {
                if reused == nil {
                    // Nothing has moved yet; leave no empty folder behind.
                    try? fileManager.removeItem(at: folder)
                }
                throw error
            }
        }

        // 1. A copy of the wallet settings, before anything changes.
        let keys = walletSettingKeys(in: settings)
        var preserved: [String: Any] = [:]
        for key in keys {
            if let value = settings.anyValue(for: key),
               PropertyListSerialization.propertyList(value, isValidFor: .binary) {
                preserved[key] = value
            }
        }
        let plist = try PropertyListSerialization.data(fromPropertyList: preserved, format: .binary, options: 0)
        let settingsName = exists(folder.appendingPathComponent("wallet-settings.plist"))
            ? "wallet-settings-\(UUID().uuidString).plist" : "wallet-settings.plist"
        let settingsURL = folder.appendingPathComponent(settingsName)
        try plist.write(to: settingsURL, options: [.atomic])
        try DurableFileWriter.synchronizeRegularFileAndContainingDirectory(at: settingsURL)

        // 2. Move (rename) the wallet files. Never delete. If one move
        // fails, the moves already done are undone, so the install is left as
        // it was; if that is not possible, the folder is marked incomplete
        // and the error says so.
        let coreDataName = "CoreData"
        try fileManager.createDirectory(
            at: folder.appendingPathComponent(coreDataName, isDirectory: true), withIntermediateDirectories: true)
        // Each move: the item now, and its place inside the folder. The
        // first four are the database file and its SQLite companions.
        let storeFileSuffixes = ["", "-wal", "-shm", "-journal"]
        var moves: [(URL, [String])] = storeFileSuffixes.map { suffix in
            (URL(fileURLWithPath: paths.storeURL.path + suffix),
             [coreDataName, paths.storeURL.lastPathComponent + suffix])
        }
        moves.append((paths.storeURL.deletingLastPathComponent()
            .appendingPathComponent("WalletMigrationSafety", isDirectory: true),
            [coreDataName, "WalletMigrationSafety"]))
        let sora = paths.applicationSupportURL.appendingPathComponent("SORA", isDirectory: true)
        for name in ["WalletNetworks", "WalletAccountCommits"] {
            moves.append((sora.appendingPathComponent(name, isDirectory: true), [name]))
        }
        // Records of unfinished transactions stay in place while they can be
        // read: they tell the restored wallets which transactions are still
        // being confirmed. A folder that cannot be read would refuse every
        // send after the restore too, so it is set aside with the rest.
        if !PendingTransactionRecords.isReadable(baseURL: paths.applicationSupportURL, fileManager: fileManager) {
            moves.append((sora.appendingPathComponent(PendingTransactionRecords.directoryName, isDirectory: true),
                           [PendingTransactionRecords.directoryName]))
        }
        func place(_ components: [String], in base: URL) -> URL {
            components.reduce(base) { $0.appendingPathComponent($1) }
        }
        // In a reused folder an item of the same name may already be there
        // from the earlier attempt (the app recreated it in between, or the
        // folder belongs to an earlier wallet). Both are kept. Everything
        // this attempt adds beside an earlier item goes into one subfolder
        // of its own, under its own name, so the items of one wallet stay
        // together. The `-wal`, `-shm` and `-journal` files follow the
        // database file this attempt moves: SQLite reads them as one.
        let laterItems = folder.appendingPathComponent(
            "later-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)", isDirectory: true)
        var databaseBase: URL?
        var done: [(URL, URL)] = []
        do {
            for (index, move) in moves.enumerated() where exists(move.0) {
                let (source, components) = move
                let isDatabaseCompanion = (1 ..< storeFileSuffixes.count).contains(index)
                var base = (isDatabaseCompanion ? databaseBase : nil) ?? folder
                if exists(place(components, in: base)) {
                    base = laterItems
                }
                let destination = place(components, in: base)
                if base == laterItems {
                    try fileManager.createDirectory(
                        at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                }
                try beforeMove(source)
                try fileManager.moveItem(at: source, to: destination)
                done.append((source, destination))
                if index == 0 {
                    databaseBase = base
                }
            }
        } catch {
            var restored = true
            for (source, destination) in done.reversed() {
                do {
                    try fileManager.moveItem(at: destination, to: source)
                } catch {
                    restored = false
                }
            }
            guard restored else {
                // The marker written in step 0 stays: a retry continues here.
                Logger.shared.warning("Wallet storage: set-aside incomplete; earlier data kept in place")
                throw Failure.incomplete(folder: folder)
            }
            if reused == nil {
                // Everything is back in place. The new folder holds only the
                // settings copy written above; remove it so a retry starts
                // clean.
                try? fileManager.removeItem(at: folder)
            } else {
                // The directories created above for this attempt are empty
                // again. `rmdir` removes an empty directory and nothing else.
                for directory in [laterItems.appendingPathComponent(coreDataName, isDirectory: true), laterItems] {
                    _ = directory.withUnsafeFileSystemRepresentation { path in
                        path.map { Darwin.rmdir($0) }
                    }
                }
            }
            throw error
        }
        try afterMoves()

        // 3. Remove the wallet settings that were copied above.
        for key in keys {
            settings.removeValue(for: key)
        }

        // 4. Everything of this wallet is in the folder now: it is complete.
        // The marker goes before the recovery marker is cleared, never
        // after. A folder that kept it once the app had left the recovery
        // screen would be taken for an unfinished attempt by a later "Set up
        // this iPhone again", months on and for another wallet, and that
        // wallet's files would be mixed into this folder. If the marker
        // cannot be removed, the recovery marker stays too and a retry
        // continues here.
        try WalletPreservedGeneration.recordComplete(folder: folder, paths: paths, fileManager: fileManager)
        try? fileManager.removeItem(at: incompleteMarkerURL)
        guard !exists(incompleteMarkerURL) else {
            Logger.shared.warning("Wallet storage: set-aside folder could not be completed; try again")
            throw Failure.incomplete(folder: folder)
        }
        try WalletPreservedGeneration.syncDirectory(folder)

        // 5. Clear the marker this screen was shown for.
        if marker.required {
            try WalletMigrationRecoveryMarker.synchronized {
                guard WalletMigrationRecoveryMarker.capture(settings) == marker else {
                    throw Failure.markerChanged
                }
                let generation = UUID().uuidString
                let cleared = WalletMigrationRecoveryMarker(
                    required: false, reason: nil, generation: generation, reasonGeneration: generation)
                WalletMigrationRecoveryMarker.publish(cleared, to: settings)
                guard WalletMigrationRecoveryMarker.capture(settings) == cleared else {
                    throw WalletNetworkMigrationError.walletRecoveryRequired
                }
            }
        }
        Logger.shared.info("Wallet storage: earlier data set aside on request; Keychain unchanged")
        return folder
    }

    private static func incompleteFolder(in root: URL, fileManager: FileManager) -> URL? {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return nil }
        return entries.sorted { $0.lastPathComponent < $1.lastPathComponent }.first { entry in
            exists(entry.appendingPathComponent(incompleteMarkerName))
        }
    }

    private static func exists(_ url: URL) -> Bool {
        var info = stat()
        return url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return lstat(path, &info) == 0
        }
    }
}

// MARK: - Helper files of interrupted writes

/// Startup sweep of the folders `DurableFileWriter` publishes into, run once
/// before any wallet storage check reads them.
///
/// A process that dies inside a durable write leaves hidden helper files
/// beside the published file. Each strict folder check also sweeps its own
/// folder when it meets one; this pass does it up front for all of them,
/// including the unfinished-transaction records, whose first check would
/// otherwise happen only when the user sends. See
/// `DurableFileWriter.sweepLeftovers` for what a sweep may remove and why
/// that is safe. No published file, key or database row is read or changed.
enum WalletInterruptedWriteCleanup {
    static func directories(
        storeURL: URL,
        applicationSupportURL: URL,
        fileManager: FileManager = .default
    ) -> [URL] {
        let sora = applicationSupportURL.appendingPathComponent("SORA", isDirectory: true)
        var directories = ["WalletNetworks", "WalletAccountCommits", PendingTransactionRecords.directoryName]
            .map { sora.appendingPathComponent($0, isDirectory: true) }
        let safety = storeURL.deletingLastPathComponent()
            .appendingPathComponent("WalletMigrationSafety", isDirectory: true)
        let attempts = (try? fileManager.contentsOfDirectory(
            at: safety, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: []
        )) ?? []
        for attempt in attempts {
            // Attempt folders only: a real directory named by a UUID.
            let values = try? attempt.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isDirectory == true, values?.isSymbolicLink != true,
                  UUID(uuidString: attempt.lastPathComponent) != nil else { continue }
            directories.append(attempt)
            directories.append(attempt.appendingPathComponent("legacy-store", isDirectory: true))
            directories.append(attempt.appendingPathComponent("staging", isDirectory: true))
        }
        return directories
    }

    /// - Returns: the number of helper files removed.
    @discardableResult
    static func run(
        storeURL: URL = UserStorageParams.storageURL,
        applicationSupportURL: URL? = nil,
        fileManager: FileManager = .default
    ) -> Int {
        guard let support = applicationSupportURL ?? (try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        )) else { return 0 }
        var removed = 0
        for directory in directories(storeURL: storeURL, applicationSupportURL: support, fileManager: fileManager) {
            removed += DurableFileWriter.sweepLeftovers(in: directory).removed
        }
        if removed > 0 {
            Logger.shared.info("Wallet storage: \(removed) helper file(s) of an interrupted write removed")
        }
        return removed
    }
}

// MARK: - Records of unfinished transactions

/// `Application Support/SORA/PendingTransactions`: the journals that record
/// transactions which were signed and may still be confirming. Every SORA2
/// send, every Nexus transfer and every Polkamarkt action first writes its
/// record there, so a folder or a journal that cannot be read means that
/// kind of transaction can never start.
///
/// The helper files of an interrupted write are swept and never count. When
/// the folder still cannot be read (an entry this version does not know, or
/// one of the three journals does not pass the read its own store begins
/// with), startup shows the recovery screen, and that screen offers to set
/// the records aside. They are moved, never deleted; accounts, keys and the
/// wallet database are not touched.
enum PendingTransactionRecords {
    static let directoryName = "PendingTransactions"

    private static func applicationSupportURL(baseURL: URL?, fileManager: FileManager) throws -> URL {
        try baseURL ?? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }

    private static func directoryURL(baseURL: URL?, fileManager: FileManager) throws -> URL {
        try applicationSupportURL(baseURL: baseURL, fileManager: fileManager)
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func exists(_ url: URL) -> Bool {
        var info = stat()
        return url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return lstat(path, &info) == 0
        }
    }

    /// Throws when a transaction would be refused because of the folder
    /// itself or because of one of its journals: the SORA2 journal (every
    /// send, swap and liquidity action), the Nexus journal and the
    /// Polkamarkt journal. Each journal goes through the read its own store
    /// begins every action with, so this fails exactly when that store
    /// would. A missing folder is a wallet that never sent anything:
    /// readable. Nothing is written.
    static func requireReadable(baseURL: URL? = nil, fileManager: FileManager = .default) throws {
        let support = try applicationSupportURL(baseURL: baseURL, fileManager: fileManager)
        let directory = try directoryURL(baseURL: baseURL, fileManager: fileManager)
        guard exists(directory) else { return }
        try PendingTransactionJournalNamespace.validate(directoryURL: directory, fileManager: fileManager)
        _ = try Sora2PendingSubmissionStore(fileManager: fileManager, baseURL: support).all()
        try NexusPendingTransactionStore.requireReadableJournal(
            applicationSupportURL: support, fileManager: fileManager)
        try PolkamarktPendingStore.requireReadableJournal(
            applicationSupportURL: support, fileManager: fileManager)
    }

    static func isReadable(baseURL: URL? = nil, fileManager: FileManager = .default) -> Bool {
        (try? requireReadable(baseURL: baseURL, fileManager: fileManager)) != nil
    }

    /// Moves the folder to `<setAsideRoot>/<time>-<id>/PendingTransactions`
    /// and leaves an empty folder in its place. Only on the user's confirmed
    /// request. Nothing is deleted; the Keychain, the wallet database and the
    /// network model are not touched.
    /// - Returns: the folder the records were moved into, or nil when there
    ///   was no folder to move.
    @discardableResult
    static func setAside(
        applicationSupportURL: URL,
        setAsideRootURL: URL,
        fileManager: FileManager = .default,
        lifecycleCoordinator: WalletLifecycleCoordinator = .shared
    ) throws -> URL? {
        // No send, removal or import holds the lease while the folder moves.
        let lease = lifecycleCoordinator.acquire()
        defer { lease.release() }
        let source = try directoryURL(baseURL: applicationSupportURL, fileManager: fileManager)
        guard exists(source) else { return nil }
        let folder = setAsideRootURL.appendingPathComponent(
            "\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            try fileManager.moveItem(at: source, to: folder.appendingPathComponent(directoryName, isDirectory: true))
        } catch {
            // Nothing moved; leave no empty folder behind.
            try? fileManager.removeItem(at: folder)
            throw error
        }
        // Stores created earlier in this process keep the old path. An empty
        // folder there is a valid "no unfinished transactions" state. If it
        // cannot be created now, the next store creates it.
        try? fileManager.createDirectory(at: source, withIntermediateDirectories: true)
        Logger.shared.info("Wallet storage: unfinished-transaction records set aside on request")
        return folder
    }
}

/// A complete preserved generation is immutable until an explicit return.
/// The return plan and Keychain receipt bind every moved file to its digest,
/// so a stopped return resumes that generation before ordinary startup.
enum WalletPreservedGeneration {
    static let manifestName = "generation.json"
    static let returnName = "RETURNING.json"
    private static let receiptPrefix = "wallet.preservedReturn."

    struct Entry: Codable, Equatable {
        let path: String
        let digest: String
    }
    struct Manifest: Codable, Equatable {
        let version: Int
        let id: UUID
        let entries: [Entry]
        let settingsDigest: String
    }
    struct Plan: Codable {
        let version: Int
        let folder: String
        let manifestDigest: String
        let id: UUID
    }
    enum Failure: Error { case invalidGeneration, liveWalletPresent, ownerPINRequired, interrupted }

    static func exists(_ url: URL) -> Bool {
        var info = stat()
        return url.withUnsafeFileSystemRepresentation { $0.map { lstat($0, &info) == 0 } ?? false }
    }

    private static func digest(_ url: URL) throws -> String {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else { throw Failure.invalidGeneration }
        if values.isDirectory == true {
            let children = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard children.count <= 4096 else { throw Failure.invalidGeneration }
            var hash = SHA256()
            for child in children {
                hash.update(data: Data(child.lastPathComponent.utf8))
                hash.update(data: Data([0]))
                hash.update(data: Data(try digest(child).utf8))
            }
            return Data(hash.finalize()).toHex()
        }
        guard values.isRegularFile == true else { throw Failure.invalidGeneration }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        return Data(hash.finalize()).toHex()
    }

    private static func destinations(_ paths: WalletLocalStateSetAside.Paths) -> [String: URL] {
        let sora = paths.applicationSupportURL.appendingPathComponent("SORA")
        var result: [String: URL] = [:]
        for suffix in ["", "-wal", "-shm", "-journal"] {
            result["CoreData/" + paths.storeURL.lastPathComponent + suffix] = URL(fileURLWithPath: paths.storeURL.path + suffix)
        }
        result["CoreData/WalletMigrationSafety"] = paths.storeURL.deletingLastPathComponent().appendingPathComponent("WalletMigrationSafety")
        for name in ["WalletNetworks", "WalletAccountCommits", PendingTransactionRecords.directoryName] {
            result[name] = sora.appendingPathComponent(name)
        }
        return result
    }

    static func recordComplete(folder: URL, paths: WalletLocalStateSetAside.Paths, fileManager: FileManager) throws {
        // A legacy interrupted set-aside can contain multiple generations.
        // Preserve it, but never guess which combination may be moved back.
        let names = try fileManager.contentsOfDirectory(atPath: folder.path)
        guard !names.contains(where: { $0.hasPrefix("later-") }) else { return }
        let entries = try destinations(paths).keys.sorted().compactMap { path -> Entry? in
            let url = folder.appendingPathComponent(path)
            return exists(url) ? Entry(path: path, digest: try digest(url)) : nil
        }
        let manifest = Manifest(version: 1, id: UUID(), entries: entries,
                                settingsDigest: try digest(folder.appendingPathComponent("wallet-settings.plist")))
        try DurableFileWriter.write(JSONEncoder().encode(manifest), to: folder.appendingPathComponent(manifestName),
                                    fileManager: fileManager, protection: .completeUntilFirstUserAuthentication)
    }

    private static func readManifest(folder: URL, paths: WalletLocalStateSetAside.Paths) throws -> Manifest {
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true,
              !exists(folder.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName)) else {
            throw Failure.invalidGeneration
        }
        let manifestURL = folder.appendingPathComponent(manifestName)
        _ = try digest(manifestURL)
        let data = try Data(contentsOf: manifestURL)
        guard data.count <= 1_048_576 else { throw Failure.invalidGeneration }
        let value = try JSONDecoder().decode(Manifest.self, from: data)
        let allowed = destinations(paths)
        guard value.version == 1, value.entries.count <= allowed.count,
              Set(value.entries.map(\.path)).count == value.entries.count,
              value.entries.allSatisfy({ allowed[$0.path] != nil && $0.digest.count == 64 }),
              try digest(folder.appendingPathComponent("wallet-settings.plist")) == value.settingsDigest else {
            throw Failure.invalidGeneration
        }
        return value
    }

    static func available(paths: WalletLocalStateSetAside.Paths, settings: SettingsManagerProtocol) -> [URL] {
        guard !settings.walletMigrationRecoveryRequired,
              WalletLocalStateSetAside.walletSettingKeys(in: settings).isEmpty,
              !exists(paths.storeURL), !exists(paths.setAsideRootURL.appendingPathComponent(returnName)) else { return [] }
        return ((try? FileManager.default.contentsOfDirectory(at: paths.setAsideRootURL,
                    includingPropertiesForKeys: nil)) ?? []).sorted { $0.lastPathComponent > $1.lastPathComponent }.filter { folder in
            guard let manifest = try? readManifest(folder: folder, paths: paths),
                  manifest.entries.contains(where: { $0.path == "CoreData/" + paths.storeURL.lastPathComponent }) else { return false }
            return manifest.entries.allSatisfy { (try? digest(folder.appendingPathComponent($0.path))) == $0.digest }
        }
    }

    static func accounts(folder: URL, paths: WalletLocalStateSetAside.Paths,
                         settings: SettingsManagerProtocol, keystore: KeystoreProtocol) throws -> [AccountItem] {
        let manifest = try readManifest(folder: folder, paths: paths)
        let database = "CoreData/" + paths.storeURL.lastPathComponent
        guard manifest.entries.contains(where: { $0.path == database }) else { return [] }
        // Core Data may create SHM files even for a read-only connection. Read
        // a private temporary copy so the preserved generation stays immutable.
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try WalletPreservedDataProtection.excludeFromBackup(temporary)
        let copy = temporary.appendingPathComponent(paths.storeURL.lastPathComponent)
        for suffix in ["", "-wal", "-shm", "-journal"] {
            let source = folder.appendingPathComponent(database + suffix)
            if exists(source) {
                try FileManager.default.copyItem(at: source, to: URL(fileURLWithPath: copy.path + suffix))
            }
        }
        return try UserStorageMigrator(targetVersion: UserStorageParams.modelVersion,
            storeURL: copy, modelDirectory: UserStorageParams.modelDirectory,
            keystore: keystore, settings: settings, fileManager: .default).preservedAccountInventory()
    }

    /// Each grant was created by a manually entered owner PIN. A new app PIN
    /// is explicitly chosen for the returned wallets; biometrics/stored PINs
    /// do not create grants. No signing key is changed.
    static func restore(folder: URL, paths: WalletLocalStateSetAside.Paths,
                        settings: SettingsManagerProtocol, keystore: KeystoreProtocol,
                        grants: [WalletOwnerPIN.RetainedAuthorization], newPIN: String,
                        lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
                        checkpoint: (String) throws -> Void = { _ in }) throws {
        let lease = lifecycleCoordinator.acquire()
        defer { lease.release() }
        guard available(paths: paths, settings: settings).contains(folder),
              folder.deletingLastPathComponent().standardizedFileURL == paths.setAsideRootURL.standardizedFileURL else {
            throw Failure.liveWalletPresent
        }
        let manifest = try readManifest(folder: folder, paths: paths)
        let rows = try accounts(folder: folder, paths: paths, settings: settings, keystore: keystore)
        let owner = WalletOwnerPIN(keystore: keystore, settings: settings,
            recoveryGate: WalletRecoveryCapabilityGate(settings: settings,
                unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false }))
        try owner.requirePreservedOwners(accounts: rows, authorizations: grants)
        // Check every destination before any authority or file is published.
        try requireEmptyDestinations(manifest: manifest, paths: paths)
        let plan = Plan(version: 1, folder: folder.lastPathComponent,
                        manifestDigest: try digest(folder.appendingPathComponent(manifestName)), id: manifest.id)
        let planData = try JSONEncoder().encode(plan)
        let receipt = Data(SHA256.hash(data: planData))
        // PIN publication uses the existing durable rotation journal. An
        // interruption here leaves the old files preserved and requires the
        // owner PIN again before another return can begin.
        try owner.setPINForPreservedRestore(newPIN, accounts: rows, authorizations: grants)
        let tag = receiptPrefix + plan.id.uuidString
        try keystore.saveKey(receipt, with: tag)
        guard try keystore.fetchKey(for: tag) == receipt else { throw Failure.interrupted }
        try DurableFileWriter.write(planData, to: paths.setAsideRootURL.appendingPathComponent(returnName),
                                    fileManager: .default, protection: .completeUntilFirstUserAuthentication)
        try checkpoint("planned")
        try resume(paths: paths, settings: settings, keystore: keystore, checkpoint: checkpoint)
    }

    private static func requireEmptyDestinations(manifest: Manifest, paths: WalletLocalStateSetAside.Paths) throws {
        for (path, target) in destinations(paths) {
            // Readable pending records deliberately survive set-aside. Other
            // live wallet files cannot be mixed into the returned generation.
            if path == PendingTransactionRecords.directoryName &&
                !manifest.entries.contains(where: { $0.path == path }) { continue }
            if exists(target) {
                let values = try target.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isDirectory == true, values.isSymbolicLink != true,
                      try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty else {
                    throw Failure.liveWalletPresent
                }
            }
        }
    }

    /// Call with the lifecycle lease held, before any database/authentication
    /// reader. An unverified or conflicting plan stops startup without writes.
    static func resume(paths: WalletLocalStateSetAside.Paths, settings: SettingsManagerProtocol,
                       keystore: KeystoreProtocol, checkpoint: (String) throws -> Void = { _ in }) throws {
        let planURL = paths.setAsideRootURL.appendingPathComponent(returnName)
        guard exists(planURL) else { return }
        _ = try digest(planURL)
        let data = try Data(contentsOf: planURL)
        let plan = try JSONDecoder().decode(Plan.self, from: data)
        guard plan.version == 1, !plan.folder.isEmpty, ![".", ".."].contains(plan.folder),
              !plan.folder.contains("/"),
              try keystore.fetchKey(for: receiptPrefix + plan.id.uuidString) == Data(SHA256.hash(data: data)) else {
            throw Failure.invalidGeneration
        }
        let folder = paths.setAsideRootURL.appendingPathComponent(plan.folder)
        guard try digest(folder.appendingPathComponent(manifestName)) == plan.manifestDigest else { throw Failure.invalidGeneration }
        let manifest = try readManifest(folder: folder, paths: paths)
        guard manifest.id == plan.id else { throw Failure.invalidGeneration }
        let targets = destinations(paths)
        for (path, target) in targets where !manifest.entries.contains(where: { $0.path == path }) &&
            path != PendingTransactionRecords.directoryName && exists(target) {
            let values = try target.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true,
                  try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty else { throw Failure.liveWalletPresent }
        }
        // Verify the whole generation on either side before resuming one move.
        for entry in manifest.entries {
            let source = folder.appendingPathComponent(entry.path), target = targets[entry.path]!
            if exists(source) {
                guard try digest(source) == entry.digest else { throw Failure.invalidGeneration }
                if exists(target) {
                    let values = try target.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    guard values.isDirectory == true, values.isSymbolicLink != true,
                          try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty else { throw Failure.liveWalletPresent }
                }
            } else {
                guard try digest(target) == entry.digest else { throw Failure.invalidGeneration }
            }
        }
        for entry in manifest.entries {
            let source = folder.appendingPathComponent(entry.path), target = targets[entry.path]!
            guard exists(source) else { continue }
            if exists(target) { try FileManager.default.removeItem(at: target) } // proven empty directory only
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: source, to: target)
            try syncDirectory(target.deletingLastPathComponent())
            try syncDirectory(source.deletingLastPathComponent())
            try checkpoint("moved:" + entry.path)
        }
        let preserved = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: folder.appendingPathComponent("wallet-settings.plist")), format: nil)
        guard let values = preserved as? [String: Any] else { throw Failure.invalidGeneration }
        // Only the same allowlist used by set-aside may restore defaults.
        for (key, value) in values {
            guard isWalletSetting(key) else { throw Failure.invalidGeneration }
            settings.set(anyValue: value, for: key)
        }
        for (key, value) in values {
            guard let actual = settings.anyValue(for: key),
                  NSDictionary(dictionary: [key: actual]).isEqual(to: [key: value]) else { throw Failure.interrupted }
        }
        try checkpoint("settingsRestored")
        try FileManager.default.removeItem(at: planURL)
        try syncDirectory(paths.setAsideRootURL)
        try keystore.deleteKeyIfExists(for: receiptPrefix + plan.id.uuidString)
        try checkpoint("finished")
    }

    private static func isWalletSetting(_ key: String) -> Bool {
        [SettingsKey.selectedAccount.rawValue, SettingsKey.decentralizedId.rawValue,
         SettingsKey.publicKeyId.rawValue, SettingsKey.hasMigrated.rawValue,
         SettingsKey.migratedAccountsV1.rawValue, SettingsKey.walletNetworkStoreVersion.rawValue,
         SettingsKey.walletStartupDiagnostic.rawValue, KeystoreTag.legacyUsername.rawValue].contains(key) ||
            key.hasPrefix("wallet.watchOnly.")
    }

    static func syncDirectory(_ url: URL) throws {
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw Failure.interrupted }
        defer { Darwin.close(fd) }
        guard Darwin.fsync(fd) == 0 else { throw Failure.interrupted }
    }
}
