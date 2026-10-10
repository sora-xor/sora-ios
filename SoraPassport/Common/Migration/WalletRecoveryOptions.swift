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

    var hasForwardActionBesidesRetry: Bool {
        canRestoreFromPhrase || canRestoreFromDrive || canRestoreExistingKeys ||
            canShowPhraseAfterPin || canReadOnly || canSetUpDeviceAgain
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
        retainedPinUsable: Bool
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
        case let .recovery(retryable, missing, withPhrase, pinUsable):
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
        return .welcomeBack(
            adoptableWallets: inventory.adoptable.count,
            walletsWithPhrase: inventory.adoptable.filter(\.hasPhrase).count,
            retainedPinUsable: WalletRetainedPinGate.isUsable(keystore: keystore, settings: settings)
        )
    }

    static func recovery(
        migrator: UserStorageMigrator,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol
    ) -> WalletRecoveryState {
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        let missing = (try? migrator.accountsForMissingKeyRecovery()) ?? []
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
            retryable: marker.isRetryableStartupFailure || marker.isDatabaseInterruption ||
                marker.isLegacyAccountCommitInterruption,
            accountsMissingKeys: missing.count,
            accountsWithPhrase: withPhrase.count,
            retainedPinUsable: WalletRetainedPinGate.isUsable(keystore: keystore, settings: settings)
        )
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
        /// moved back. Nothing was deleted; the wallet settings and the
        /// recovery marker were left as they were. A retry continues in the
        /// same folder.
        case incomplete(folder: URL)
    }

    /// Written into a set-aside folder whose moves did not all complete, and
    /// removed when they do. A retry reuses that folder.
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
        closeDatabase: () -> Void = {},
        beforeMove: (URL) throws -> Void = { _ in }
    ) throws -> URL {
        let lease = lifecycleCoordinator.acquire()
        defer { lease.release() }
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
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

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
        let settingsName = reused == nil ? "wallet-settings.plist" : "wallet-settings-\(UUID().uuidString).plist"
        try plist.write(to: folder.appendingPathComponent(settingsName), options: [.atomic])

        // 2. Move (rename) the wallet files. Never delete. If one move
        // fails, the moves already done are undone, so the install is left as
        // it was; if that is not possible, the folder is marked incomplete
        // and the error says so.
        let coreData = folder.appendingPathComponent("CoreData", isDirectory: true)
        try fileManager.createDirectory(at: coreData, withIntermediateDirectories: true)
        var moves: [(URL, URL)] = ["", "-wal", "-shm", "-journal"].map { suffix in
            (URL(fileURLWithPath: paths.storeURL.path + suffix),
             coreData.appendingPathComponent(paths.storeURL.lastPathComponent + suffix))
        }
        moves.append((paths.storeURL.deletingLastPathComponent()
            .appendingPathComponent("WalletMigrationSafety", isDirectory: true),
            coreData.appendingPathComponent("WalletMigrationSafety", isDirectory: true)))
        let sora = paths.applicationSupportURL.appendingPathComponent("SORA", isDirectory: true)
        for name in ["WalletNetworks", "WalletAccountCommits"] {
            moves.append((sora.appendingPathComponent(name, isDirectory: true),
                           folder.appendingPathComponent(name, isDirectory: true)))
        }
        var done: [(URL, URL)] = []
        do {
            for (source, plannedDestination) in moves where exists(source) {
                // In a reused folder an item of the same name may already be
                // there from the earlier attempt; keep both.
                let destination = exists(plannedDestination)
                    ? plannedDestination.deletingLastPathComponent().appendingPathComponent(
                        plannedDestination.lastPathComponent + "." + UUID().uuidString)
                    : plannedDestination
                try beforeMove(source)
                try fileManager.moveItem(at: source, to: destination)
                done.append((source, destination))
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
                try? Data("Some wallet files were moved here and others were not. Nothing was deleted.".utf8)
                    .write(to: folder.appendingPathComponent(incompleteMarkerName), options: [.atomic])
                Logger.shared.warning("Wallet storage: set-aside incomplete; earlier data kept in place")
                throw Failure.incomplete(folder: folder)
            }
            if reused == nil {
                // Everything is back in place. The new folder holds only the
                // settings copy written above; remove it so a retry starts
                // clean.
                try? fileManager.removeItem(at: folder)
            }
            throw error
        }
        if exists(folder.appendingPathComponent(incompleteMarkerName)) {
            try? fileManager.removeItem(at: folder.appendingPathComponent(incompleteMarkerName))
        }

        // 3. Remove the wallet settings that were copied above.
        for key in keys {
            settings.removeValue(for: key)
        }

        // 4. Clear the marker this screen was shown for.
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
