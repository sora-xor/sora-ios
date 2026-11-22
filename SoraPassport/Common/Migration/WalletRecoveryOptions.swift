// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SoraKeystore
import CryptoKit
import IrohaCrypto
import SQLite3
import SSFUtils

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

// MARK: - Account rows read straight from a database file

/// The account rows of a wallet database file, read with SQLite on a private
/// copy. It needs no Core Data model, so it also reads a store whose schema
/// this version does not know, and one with malformed rows. Public account
/// data only. The file itself is never opened or changed.
enum WalletStoreAccountScan {
    struct Row: Equatable {
        let address: String
        let publicKey: Data?
        let cryptoType: Int?
        let networkType: Int?
        let username: String?
        let order: Int?
        let isSelected: Bool
    }

    enum Result: Equatable {
        /// No such file.
        case missing
        /// The file exists but cannot be read now (locked device, I/O). This
        /// says nothing about the wallet, so nothing may be moved because of it.
        case inaccessible
        /// The rows that could be read, when enumeration did not finish or met
        /// rows with no usable identity. They name wallets; a row that is absent
        /// here is not evidence of a removed wallet.
        case incomplete([Row])
        /// Bytes that are not a database, or a database SQLite reports as damaged.
        case unreadable
        /// A readable database and its rows, which may be none. An empty file
        /// counts as no rows: it is what a stopped first write leaves.
        case rows([Row])
    }

    private static let maximumRows = 4_096
    private static let header = Data("SQLite format 3\u{0}".utf8)

    static func read(storeURL: URL, fileManager: FileManager = .default) -> Result {
        var info = stat()
        var lookupError: Int32 = 0
        let found = storeURL.withUnsafeFileSystemRepresentation { path -> Bool in
            guard let path else {
                lookupError = EINVAL
                return false
            }
            if Darwin.lstat(path, &info) == 0 { return true }
            lookupError = errno
            return false
        }
        guard found else { return lookupError == ENOENT ? .missing : .inaccessible }
        guard (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return .unreadable }
        guard info.st_size > 0 else { return .rows([]) }

        guard let handle = try? FileHandle(forReadingFrom: storeURL) else { return .inaccessible }
        defer { try? handle.close() }
        guard let start = try? handle.read(upToCount: header.count) else { return .inaccessible }
        guard start == header else { return .unreadable }

        // Opening a database can write to it (WAL recovery, shared memory).
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("wallet-store-scan-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: directory) }
        let copy = directory.appendingPathComponent(storeURL.lastPathComponent)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try fileManager.copyItem(at: storeURL, to: copy)
        } catch {
            return .inaccessible
        }
        for suffix in ["-wal", "-shm", "-journal"] {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            var companion = stat()
            var companionError: Int32 = 0
            let exists = source.withUnsafeFileSystemRepresentation { path -> Bool in
                guard let path else { companionError = EINVAL; return false }
                if Darwin.lstat(path, &companion) == 0 { return true }
                companionError = errno
                return false
            }
            if !exists {
                guard companionError == ENOENT else { return .inaccessible }
                continue
            }
            // A committed account may exist only in the WAL. Omitting any
            // existing companion can turn an old main file into a false,
            // apparently complete inventory.
            guard (companion.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return .inaccessible }
            do {
                try fileManager.copyItem(at: source, to: URL(fileURLWithPath: copy.path + suffix))
            } catch {
                return .inaccessible
            }
        }
        return query(databaseAt: copy)
    }

    private static func query(databaseAt url: URL) -> Result {
        var opened: OpaquePointer?
        defer { sqlite3_close(opened) }
        guard sqlite3_open_v2(url.path, &opened, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let database = opened else { return .unreadable }

        var pragma: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA table_info(ZCDACCOUNTITEM)", -1, &pragma, nil) == SQLITE_OK else {
            sqlite3_finalize(pragma)
            return .unreadable
        }
        var columns = Set<String>()
        var step = sqlite3_step(pragma)
        while step == SQLITE_ROW {
            if let name = sqlite3_column_text(pragma, 1) { columns.insert(String(cString: name)) }
            step = sqlite3_step(pragma)
        }
        sqlite3_finalize(pragma)
        guard step == SQLITE_DONE else { return .unreadable }
        // A database with no such table never held an account.
        guard columns.contains("ZIDENTIFIER") else { return .rows([]) }

        let wanted = ["ZIDENTIFIER", "ZPUBLICKEY", "ZCRYPTOTYPE", "ZNETWORKTYPE", "ZUSERNAME", "ZORDER", "ZISSELECTED"]
            .filter(columns.contains)
        let position = Dictionary(uniqueKeysWithValues: wanted.enumerated().map { ($0.element, Int32($0.offset)) })
        var select: OpaquePointer?
        defer { sqlite3_finalize(select) }
        guard sqlite3_prepare_v2(database, "SELECT \(wanted.joined(separator: ", ")) FROM ZCDACCOUNTITEM",
                                 -1, &select, nil) == SQLITE_OK else { return .unreadable }

        func isNull(_ column: String) -> Bool {
            position[column].map { sqlite3_column_type(select, $0) == SQLITE_NULL } ?? true
        }
        func integer(_ column: String) -> Int? {
            guard !isNull(column), let index = position[column] else { return nil }
            return Int(sqlite3_column_int64(select, index))
        }
        func text(_ column: String) -> String? {
            guard !isNull(column), let index = position[column],
                  let value = sqlite3_column_text(select, index) else { return nil }
            return String(cString: value)
        }
        func blob(_ column: String) -> Data? {
            guard !isNull(column), let index = position[column],
                  let bytes = sqlite3_column_blob(select, index) else { return nil }
            return Data(bytes: bytes, count: Int(sqlite3_column_bytes(select, index)))
        }

        var rows: [Row] = []
        var identifiers = Set<String>()
        var metUnusableRow = false
        var inspectedRows = 0
        step = sqlite3_step(select)
        while step == SQLITE_ROW, inspectedRows < maximumRows {
            inspectedRows += 1
            if let address = text("ZIDENTIFIER"), !address.isEmpty {
                if identifiers.insert(address).inserted {
                    rows.append(Row(address: address, publicKey: blob("ZPUBLICKEY"), cryptoType: integer("ZCRYPTOTYPE"),
                                    networkType: integer("ZNETWORKTYPE"), username: text("ZUSERNAME"),
                                    order: integer("ZORDER"), isSelected: integer("ZISSELECTED") == 1))
                }
            } else {
                metUnusableRow = true
            }
            step = sqlite3_step(select)
        }
        // SQLITE_ROW here means the bounded scan omitted at least one row;
        // an error can occur after any number of otherwise valid accounts.
        guard step == SQLITE_DONE, !metUnusableRow else { return .incomplete(rows) }
        return .rows(rows)
    }
}

// MARK: - Automatic repair at startup

/// An update never stops on a question. The user had a wallet, updated the app
/// and gets the same wallet behind the same PIN, whatever the earlier version
/// left in the app's files. When those files cannot be used, they are moved
/// aside (never deleted) and the wallet database is written again.
///
/// The Keychain is never written or deleted here. Which wallets come back:
///
/// - Only wallets this installation's own files name: database rows, retained
///   copies of the database, the selected-account setting, the network
///   snapshot. iOS deletes all of them with the app, so a reinstall never
///   reaches this path and retained wallets stay behind Welcome back and their
///   owner PIN. This matters because a typed app PIN claims every proven row
///   in the database (`WalletOwnerPIN.authenticateCurrent`).
/// - A database that exists and cannot be read is itself proof of an earlier
///   wallet here, and the normal app cannot produce one. If nothing here names
///   a wallet, the wallets the Keychain proves come back, if a PIN exists. A
///   folder an earlier version set aside counts the same way, unless the user
///   chose to set this iPhone up again here (`recordSetUpAgainChoice`).
/// - A database that can only be read in part is rebuilt from an independently
///   complete repair plan or current network snapshot. Its surviving rows alone
///   cannot become a complete replacement and silently hide the other wallets.
/// - Every signing row is proved by its own keys, with the same checks as any
///   startup. A row of the database with no proving keys stays read-only. A
///   name from anywhere else needs its keys, and no owner record may say that
///   the current PIN is not its owner's.
///
/// Routing then runs as on any launch, so the PIN screen is still the check.
enum WalletDatabaseSelfRepair {
    /// Public account data of a repair in progress, so a repair stopped after
    /// files moved finishes on the next launch.
    static let planKey = "wallet.selfRepairPlan"
    private static let setUpAgainChosenKey = "wallet.setUpAgainChosen"

    /// The user chose "Set up this iPhone again" in this version. Files set
    /// aside before that stay where they are: a later start must not undo the
    /// choice. Files an earlier version set aside were set aside by someone
    /// stuck on its recovery screen, and those wallets do come back.
    static func recordSetUpAgainChoice(_ settings: SettingsManagerProtocol) {
        settings.set(value: true, for: setUpAgainChosenKey)
    }

    struct Environment {
        let settings: SettingsManagerProtocol
        let keystore: KeystoreProtocol
        let paths: WalletLocalStateSetAside.Paths
        /// Writes the new database in the current schema.
        let databaseWriter: UserStorageMigrator
        var fileManager: FileManager = .default
        var lifecycleCoordinator: WalletLifecycleCoordinator = .shared

        fileprivate var storeName: String { paths.storeURL.lastPathComponent }
        fileprivate var safetyURL: URL {
            paths.storeURL.deletingLastPathComponent().appendingPathComponent("WalletMigrationSafety", isDirectory: true)
        }
        fileprivate var soraURL: URL {
            paths.applicationSupportURL.appendingPathComponent("SORA", isDirectory: true)
        }
        fileprivate var proofGate: WalletRecoveryCapabilityGate {
            .forStartupSelfRepairProof(settings: settings)
        }
    }

    private enum Failure: Error {
        case databaseInaccessible
        case incompleteInventory
        case invalidRepairPlan
        case rebuiltDatabaseDiffers
    }

    private struct Known {
        var publicKey: Data?
        var cryptoType: CryptoType?
        var networkType: SNAddressType?
        var username: String?
        var order: Int16?
        var isSelected = false
        var assets: AccountSettings?

        init(publicKey: Data? = nil, cryptoType: CryptoType? = nil, networkType: SNAddressType? = nil,
             username: String? = nil, order: Int16? = nil, isSelected: Bool = false, assets: AccountSettings? = nil) {
            self.publicKey = publicKey
            self.cryptoType = cryptoType
            self.networkType = networkType
            self.username = username
            self.order = order
            self.isSelected = isSelected
            self.assets = assets
        }

        init(_ row: WalletStoreAccountScan.Row) {
            publicKey = row.publicKey
            cryptoType = row.cryptoType.flatMap { UInt8(exactly: $0) }.flatMap(CryptoType.init(rawValue:))
            networkType = row.networkType.flatMap { SNAddressType(exactly: $0) }
            username = row.username
            order = row.order.flatMap { Int16(exactly: $0) }
            isSelected = row.isSelected
        }

        init(_ account: AccountItem, isSelected: Bool) {
            self.init(publicKey: account.publicKeyData, cryptoType: account.cryptoType,
                      networkType: account.networkType, username: account.username, order: account.order,
                      isSelected: isSelected, assets: account.settings)
        }

        /// Earlier sources win; a later one only fills what is still unknown.
        mutating func fill(from other: Known) {
            publicKey = publicKey ?? other.publicKey
            cryptoType = cryptoType ?? other.cryptoType
            networkType = networkType ?? other.networkType
            username = username ?? other.username
            order = order ?? other.order
            isSelected = isSelected || other.isSelected
            assets = assets ?? other.assets
        }
    }

    private struct Inventory {
        var liveRows: [String: Known] = [:]
        /// A saved full inventory, including keyless rows, from this repair.
        /// A restart must restore every identity before clearing this plan.
        var plannedAccounts: [AccountItem]?
        /// Named by the installation's other records. Used only when the live
        /// database has no usable row.
        var named: [String: Known] = [:]
        /// Those of `named` that a partly readable database itself lists. Like
        /// any database row they belong here, and may stay read-only.
        var salvagedRows = Set<String>()
        /// Every identity in a validated current snapshot must survive repair,
        /// including wallets whose database page and signing keys are gone.
        var requiredAddresses: Set<String>?
        var snapshotRows = Set<String>()
        /// App Store 3.8.6 removed only mnemonic entropy, leaving seed/secret
        /// copies. Those leftovers must not undo its committed row deletion.
        var legacyRemovedAddresses = Set<String>()

        mutating func addNamed(_ address: String, _ known: Known) {
            if named[address] == nil {
                named[address] = known
            } else {
                named[address]?.fill(from: known)
            }
        }
    }

    // MARK: Entry points

    /// Before the ordinary checks: the database is gone or holds no account
    /// while this installation's files name wallets whose keys are here.
    /// Returns true when it changed anything.
    @discardableResult
    static func restoreLostDatabase(_ environment: Environment) -> Bool {
        // A stopped return of a preserved wallet finishes on its own path.
        let returning = environment.paths.setAsideRootURL.appendingPathComponent(WalletPreservedGeneration.returnName)
        guard !WalletPreservedGeneration.exists(returning) else { return false }
        do {
            let databaseIsEmpty: Bool
            switch WalletStoreAccountScan.read(storeURL: environment.paths.storeURL, fileManager: environment.fileManager) {
            case .missing:
                databaseIsEmpty = false
            case let .rows(rows) where rows.isEmpty:
                databaseIsEmpty = true
                if environment.settings.anyValue(for: planKey) == nil,
                   try isUnclaimedLegacyWallet(environment) {
                    // The 1.x upgrade runs only when no database exists; an
                    // empty file must not hold it up. The settings it reads stay.
                    try setAside(environment, includingDatabase: true, derivedState: false)
                    return true
                }
            case .rows:
                guard environment.settings.anyValue(for: planKey) != nil else { return false }
                databaseIsEmpty = false
            case .unreadable, .incomplete:
                guard environment.settings.anyValue(for: planKey) != nil else { return false }
                databaseIsEmpty = false
            case .inaccessible:
                return false
            }
            // An interrupted import is resolved by the ordinary checks first:
            // they know whether its row should exist.
            guard try !hasUnfinishedAccountCommit(environment) else { return false }
            let inventory = try inventory(environment)
            let accounts = try restorableAccounts(from: inventory, environment: environment)
            guard !accounts.isEmpty else {
                if !inventory.legacyRemovedAddresses.isEmpty {
                    // The legacy user's removal must also survive moving the
                    // stale snapshot aside; its leftover seeds cannot undo it.
                    recordSetUpAgainChoice(environment.settings)
                }
                // An empty database beside records of a wallet whose keys are
                // gone. Left in place it stops at routing on every launch, even
                // when the database checks themselves pass.
                if databaseIsEmpty, environment.databaseWriter.retainedWalletEvidenceKind() == .durable {
                    try WalletLocalStateSetAside.setAside(
                        settings: environment.settings, expectedMarker: nil, paths: environment.paths,
                        fileManager: environment.fileManager, lifecycleCoordinator: environment.lifecycleCoordinator)
                    Logger.shared.info("Wallet storage: earlier files set aside; no wallet here can be proved")
                    return true
                }
                return false
            }
            try publish(accounts, environment: environment)
            Logger.shared.info("Wallet storage: lost database rebuilt for \(accounts.count) account(s)")
            return true
        } catch {
            Logger.shared.warning(
                "Wallet storage: automatic repair deferred (\(UserStorageMigrationError.privacySafeOutcomeCode(for: error)))"
            )
            return false
        }
    }

    /// After the ordinary checks stopped, for any reason. First everything
    /// built from a readable database is set aside and rebuilt; if that is not
    /// enough, the database itself is written again. When no wallet can come
    /// back, the files are set aside and routing continues from what is left.
    /// Only a Keychain or file error it cannot get past leaves the outcome as
    /// it was, for the next launch to retry.
    static func recover(
        _ environment: Environment,
        ordinaryChecks: () -> WalletStorageStartupOutcome
    ) -> WalletStorageStartupOutcome {
        do {
            let inventory = try inventory(environment)
            let accounts = try restorableAccounts(from: inventory, environment: environment)
            if !accounts.isEmpty { savePlan(accounts, environment: environment) }

            if !inventory.liveRows.isEmpty {
                try setAside(environment, includingDatabase: false, derivedState: true)
                environment.settings.removeValue(for: SettingsKey.walletNetworkStoreVersion.rawValue)
                clearMarker(environment.settings)
                let outcome = ordinaryChecks()
                guard outcome == .recoveryRequired else {
                    environment.settings.removeValue(for: planKey)
                    Logger.shared.info("Wallet storage: startup state rebuilt from the wallet database")
                    return outcome
                }
            }

            if accounts.isEmpty {
                if !inventory.legacyRemovedAddresses.isEmpty {
                    recordSetUpAgainChoice(environment.settings)
                }
                try WalletLocalStateSetAside.setAside(
                    settings: environment.settings, expectedMarker: nil, paths: environment.paths,
                    fileManager: environment.fileManager, lifecycleCoordinator: environment.lifecycleCoordinator)
                Logger.shared.info("Wallet storage: earlier files set aside; no wallet here can be proved")
            } else {
                try publish(accounts, environment: environment)
                Logger.shared.info("Wallet storage: database rebuilt for \(accounts.count) account(s)")
            }
            return ordinaryChecks()
        } catch {
            Logger.shared.warning(
                "Wallet storage: automatic repair deferred (\(UserStorageMigrationError.privacySafeOutcomeCode(for: error)))"
            )
            return .recoveryRequired
        }
    }

    // MARK: The database version 3.9.3 could not read

    /// Set once this installation was checked for a database that version
    /// 3.9.3 set aside without having read it.
    static let unreadDatabaseCheckedKey = "wallet.unreadDatabaseReturn.checked"

    /// Version 3.9.3 could not read the version stamp of any wallet database
    /// on a real iPhone (`NSPersistentStoreCoordinator.readOnlyMetadata`). On
    /// every launch it set the database aside, wrote a new one from the
    /// account rows alone and stopped on the recovery screen anyway. Wallet
    /// names and token lists stayed in the folder of its first attempt, and
    /// "Set up this iPhone again" on that screen set the rest aside as well.
    ///
    /// Nothing was wrong with that first database. It comes back, once, when
    /// the wallet here now is the same one or none:
    ///
    /// - every account row here now must be a row of it, so a wallet created
    ///   or imported since is never replaced;
    /// - a row of it that is not here now needs its own keys (or its
    ///   watch-only record) and an app PIN that no owner record objects to,
    ///   as for any wallet this repair names.
    ///
    /// What is here now is set aside like everything before it. The ordinary
    /// checks then run on the returned database as on any update. Returns
    /// true when it changed anything.
    @discardableResult
    static func returnDatabaseSetAsideUnread(_ environment: Environment) -> Bool {
        let settings = environment.settings
        let fileManager = environment.fileManager
        guard settings.bool(for: unreadDatabaseCheckedKey) != true else { return false }
        // A stopped return of a preserved wallet finishes on its own path.
        let returning = environment.paths.setAsideRootURL.appendingPathComponent(WalletPreservedGeneration.returnName)
        guard !WalletPreservedGeneration.exists(returning) else { return false }
        do {
            let candidates = foldersSetAsideUnread(environment)
            guard !candidates.isEmpty else {
                settings.set(value: true, for: unreadDatabaseCheckedKey)
                return false
            }
            // An interrupted import is resolved by the ordinary checks first.
            guard try !hasUnfinishedAccountCommit(environment) else { return false }
            let here: [WalletStoreAccountScan.Row]
            switch WalletStoreAccountScan.read(storeURL: environment.paths.storeURL, fileManager: fileManager) {
            case .missing: here = []
            case let .rows(rows): here = rows
            // Nothing can be compared now. The repair below deals with this
            // file, and a later launch decides.
            case .inaccessible, .unreadable, .incomplete: return false
            }
            var planned: [AccountItem] = []
            if settings.anyValue(for: planKey) != nil {
                guard let plan = settings.value(of: [AccountItem].self, for: planKey) else { return false }
                planned = plan
            }

            let folder = try newSetAsideFolder(environment)
            var beganPreservingOriginals = false
            defer {
                // Until the first live move this folder holds only copies.
                if !beganPreservingOriginals { try? fileManager.removeItem(at: folder) }
            }
            let stagedDirectory = folder.appendingPathComponent("returned", isDirectory: true)
            try fileManager.createDirectory(at: stagedDirectory, withIntermediateDirectories: true)
            let staged = stagedDirectory.appendingPathComponent(environment.storeName)

            // The oldest folder whose database is a readable wallet database
            // is the one the user had; the later ones hold rebuilt copies.
            var found: (rows: [WalletStoreAccountScan.Row], settings: [String: Any])?
            for candidate in candidates {
                for suffix in ["", "-wal", "-shm", "-journal"] {
                    try? fileManager.removeItem(at: URL(fileURLWithPath: staged.path + suffix))
                }
                guard let rows = try stageDatabase(from: candidate, at: staged, environment: environment),
                      let data = try? Data(contentsOf: candidate.appendingPathComponent("wallet-settings.plist")),
                      let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                else { continue }
                found = (rows, values)
                break
            }
            guard let found else {
                settings.set(value: true, for: unreadDatabaseCheckedKey)
                return false
            }

            func isRow(_ row: WalletStoreAccountScan.Row, of rows: [WalletStoreAccountScan.Row]) -> Bool {
                rows.contains {
                    $0.address == row.address && $0.publicKey == row.publicKey &&
                        $0.cryptoType == row.cryptoType && $0.networkType == row.networkType
                }
            }
            let plannedRows = planned.map {
                WalletStoreAccountScan.Row(address: $0.address, publicKey: $0.publicKeyData,
                                           cryptoType: Int($0.cryptoType.rawValue), networkType: Int($0.networkType),
                                           username: nil, order: nil, isSelected: false)
            }
            guard (here + plannedRows).allSatisfy({ isRow($0, of: found.rows) }) else {
                // Another wallet is here now. It stays, and so does the folder.
                settings.set(value: true, for: unreadDatabaseCheckedKey)
                return false
            }
            let arriving = found.rows.filter { row in !here.contains { $0.address == row.address } }
            if !arriving.isEmpty {
                let owner = WalletOwnerPIN(keystore: environment.keystore, settings: settings,
                                           recoveryGate: environment.proofGate)
                var mayArrive = try environment.keystore.checkKey(for: KeystoreTag.pincode.rawValue)
                for row in arriving where mayArrive {
                    let isWatchOnly = found.settings["wallet.watchOnly.\(row.address)"] as? Bool == true
                    mayArrive = try owner.currentPINMayOwn(address: row.address) &&
                        (isWatchOnly || proof(for: row.address, environment: environment) != nil)
                }
                guard mayArrive else {
                    settings.set(value: true, for: unreadDatabaseCheckedKey)
                    return false
                }
            }

            var preserved: [String: Any] = [:]
            for key in WalletLocalStateSetAside.walletSettingKeys(in: settings) {
                if let value = settings.anyValue(for: key),
                   PropertyListSerialization.propertyList(value, isValidFor: .binary) {
                    preserved[key] = value
                }
            }
            let plist = try PropertyListSerialization.data(fromPropertyList: preserved, format: .binary, options: 0)
            try plist.write(to: folder.appendingPathComponent("wallet-settings.plist"), options: [.atomic])

            beganPreservingOriginals = true
            try setAside(environment, includingDatabase: true, derivedState: true, into: folder)

            let lease = environment.lifecycleCoordinator.acquire()
            defer { lease.release() }
            try fileManager.createDirectory(at: environment.paths.storeURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
            // One file, so one rename: a stop here leaves either no database
            // (this runs again) or the whole returned one.
            try fileManager.moveItem(at: staged, to: environment.paths.storeURL)

            let returnedKeys: Set<String> = [
                SettingsKey.selectedAccount.rawValue, SettingsKey.decentralizedId.rawValue,
                SettingsKey.publicKeyId.rawValue, SettingsKey.hasMigrated.rawValue,
                SettingsKey.migratedAccountsV1.rawValue, KeystoreTag.legacyUsername.rawValue,
            ]
            for (key, value) in found.settings where returnedKeys.contains(key) || key.hasPrefix("wallet.watchOnly.") {
                settings.set(anyValue: value, for: key)
            }
            for key in settings.allKeys() where key.hasPrefix("wallet.watchOnly.") && found.settings[key] == nil {
                settings.removeValue(for: key)
            }
            // Rebuilt from the returned rows at this launch's network bootstrap.
            settings.removeValue(for: SettingsKey.walletNetworkStoreVersion.rawValue)
            settings.removeValue(for: SettingsKey.walletStartupDiagnostic.rawValue)
            clearMarker(settings)
            settings.removeValue(for: planKey)
            // That choice was made on a screen that should never have appeared.
            settings.removeValue(for: setUpAgainChosenKey)
            settings.set(value: true, for: unreadDatabaseCheckedKey)
            Logger.shared.info("Wallet storage: the database an earlier version set aside unread is back in place")
            return true
        } catch {
            Logger.shared.warning(
                "Wallet storage: return of the earlier database deferred (\(UserStorageMigrationError.privacySafeOutcomeCode(for: error)))"
            )
            return false
        }
    }

    /// The folders version 3.9.3 filled because it could not read the version
    /// stamp, oldest first. Its repair saved the wallet settings beside each
    /// database it set aside, with the failure it had just recorded.
    private static func foldersSetAsideUnread(_ environment: Environment) -> [URL] {
        let folders = (try? environment.fileManager.contentsOfDirectory(
            at: environment.paths.setAsideRootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        let dated = folders.compactMap { folder -> (seconds: Int, folder: URL)? in
            let name = folder.lastPathComponent
            guard let dash = name.firstIndex(of: "-"), let seconds = Int(name[..<dash]),
                  UUID(uuidString: String(name[name.index(after: dash)...])) != nil,
                  let kind = try? folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  kind.isDirectory == true, kind.isSymbolicLink != true,
                  !WalletPreservedGeneration.exists(
                      folder.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName)),
                  let data = try? Data(contentsOf: folder.appendingPathComponent("wallet-settings.plist")),
                  let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let recorded = values[SettingsKey.walletStartupDiagnostic.rawValue] as? String,
                  let failure = try? JSONDecoder().decode(WalletStartupDiagnostic.self, from: Data(recorded.utf8)),
                  failure.phase == .databaseMigration, failure.cause == .unknownStore else { return nil }
            return (seconds, folder)
        }
        return dated.sorted {
            $0.seconds != $1.seconds ? $0.seconds < $1.seconds : $0.folder.lastPathComponent < $1.folder.lastPathComponent
        }.map(\.folder)
    }

    /// A copy at `staged` of the database set aside in `folder`, as one file
    /// with the pages of its write-ahead log folded in (the form
    /// `writeRepairedStore` writes), and its account rows.
    /// Nil when that file is not a wallet database this app knows or names no
    /// account. A copy that cannot be opened or folded now says nothing about
    /// the file, so that throws and a later launch tries again. The folder
    /// itself is not changed.
    private static func stageDatabase(
        from folder: URL, at staged: URL, environment: Environment
    ) throws -> [WalletStoreAccountScan.Row]? {
        let fileManager = environment.fileManager
        let source = folder.appendingPathComponent("CoreData", isDirectory: true)
            .appendingPathComponent(environment.storeName)
        // Not the `-shm` index: SQLite builds it again from the log itself,
        // which cannot disagree with the log the way a copied index could.
        for suffix in ["", "-wal", "-journal"] {
            let part = URL(fileURLWithPath: source.path + suffix)
            var info = stat()
            let found = part.withUnsafeFileSystemRepresentation { path in path.map { Darwin.lstat($0, &info) == 0 } ?? false }
            guard found else {
                if suffix.isEmpty { return nil }
                continue
            }
            guard (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else { return nil }
            try fileManager.copyItem(at: part, to: URL(fileURLWithPath: staged.path + suffix))
        }
        var opened: OpaquePointer?
        guard sqlite3_open_v2(staged.path, &opened, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let database = opened else {
            sqlite3_close(opened)
            throw Failure.databaseInaccessible
        }
        // Out of write-ahead mode, as a statement that reports the result:
        // SQLite folds every page of the log into the file and removes the
        // log. (`sqlite3_wal_checkpoint_v2` on a connection that has not read
        // yet has no log open and returns success having done nothing; and a
        // file left in write-ahead mode without its log cannot be opened
        // read-only at all, which is how the version stamp is read.)
        var statement: OpaquePointer?
        let prepared = sqlite3_prepare_v2(database, "PRAGMA journal_mode=DELETE", -1, &statement, nil)
        let stepped = prepared == SQLITE_OK ? sqlite3_step(statement) : prepared
        let mode = stepped == SQLITE_ROW ? sqlite3_column_text(statement, 0).map { String(cString: $0) } : nil
        sqlite3_finalize(statement)
        sqlite3_close(database)
        // Bytes that are not a database are an answer; anything else is not.
        if [prepared, stepped].contains(where: { $0 == SQLITE_NOTADB || $0 == SQLITE_CORRUPT }) { return nil }
        guard mode == "delete" else { throw Failure.databaseInaccessible }
        // The log's copy must be gone or empty: no page is dropped with it.
        let log = URL(fileURLWithPath: staged.path + "-wal")
        if WalletPreservedGeneration.exists(log) {
            guard let size = try fileManager.attributesOfItem(atPath: log.path)[.size] as? NSNumber,
                  size.int64Value == 0 else { throw Failure.databaseInaccessible }
            try fileManager.removeItem(at: log)
        }
        try? fileManager.removeItem(at: URL(fileURLWithPath: staged.path + "-shm"))
        guard !WalletPreservedGeneration.exists(URL(fileURLWithPath: staged.path + "-journal")) else {
            throw Failure.databaseInaccessible
        }
        guard environment.databaseWriter.isKnownWalletDatabase(at: staged),
              case let .rows(rows) = WalletStoreAccountScan.read(storeURL: staged, fileManager: fileManager),
              !rows.isEmpty else { return nil }
        return rows
    }

    // MARK: What the installation knows

    private static func isUnclaimedLegacyWallet(_ environment: Environment) throws -> Bool {
        try LegacyWalletUpgradePolicy.isProvenCandidate(
            keystore: environment.keystore,
            hasWatchOnlyWallet: environment.settings.hasRetainedWatchOnlyWallet(),
            snapshot: networkSnapshot(environment)
        )
    }

    private static func hasUnfinishedAccountCommit(_ environment: Environment) throws -> Bool {
        try !WalletAccountCommitJournalStore(
            fileManager: environment.fileManager,
            baseURL: environment.paths.applicationSupportURL,
            recoveryGate: environment.proofGate
        ).unresolved().isEmpty
    }

    private static func networkSnapshot(_ environment: Environment) -> WalletNetworkSnapshot? {
        let directory = environment.soraURL.appendingPathComponent("WalletNetworks", isDirectory: true)
        guard environment.fileManager.fileExists(atPath: directory.path) else { return nil }
        return try? WalletNetworkStore(
            fileManager: environment.fileManager,
            baseURL: environment.paths.applicationSupportURL,
            recoveryGate: environment.proofGate
        ).load()
    }

    private static func inventory(_ environment: Environment) throws -> Inventory {
        let fileManager = environment.fileManager
        let settings = environment.settings
        let live = WalletStoreAccountScan.read(storeURL: environment.paths.storeURL, fileManager: fileManager)
        if live == .inaccessible { throw Failure.databaseInaccessible }

        var result = Inventory()
        if settings.anyValue(for: planKey) != nil {
            guard let plan = settings.value(of: [AccountItem].self, for: planKey),
                  !plan.isEmpty, plan.count <= 4_096,
                  Set(plan.map(\.address)).count == plan.count else {
                throw Failure.invalidRepairPlan
            }
            let readableRows: [WalletStoreAccountScan.Row]
            switch live {
            case let .rows(rows), let .incomplete(rows): readableRows = rows
            default: readableRows = []
            }
            if !readableRows.isEmpty {
                // A stale plan cannot discard accounts from another live
                // generation. Preserve both sources until they can reconcile.
                guard Set(readableRows.map(\.address)).isSubset(of: Set(plan.map(\.address))) else {
                    throw Failure.invalidRepairPlan
                }
            }
            // The plan precedes moving any live files. It remains the complete
            // expected inventory even after some or all of those moves finish.
            result.plannedAccounts = plan
            for account in plan { result.addNamed(account.address, Known(account, isSelected: account.isSelected)) }
            return result
        }
        if case let .rows(rows) = live {
            for row in rows where result.liveRows[row.address] == nil {
                result.liveRows[row.address] = Known(row)
            }
        }
        // Rows the live database has decide: an account it no longer lists may
        // have been removed on purpose.
        guard result.liveRows.isEmpty else { return result }

        var liveFileIsDamaged = live == .unreadable
        if case let .incomplete(rows) = live {
            liveFileIsDamaged = true
            for row in rows {
                result.addNamed(row.address, Known(row))
                result.salvagedRows.insert(row.address)
            }
        }
        for copy in retainedDatabaseCopies(environment) {
            if case let .rows(rows) = WalletStoreAccountScan.read(storeURL: copy, fileManager: fileManager) {
                for row in rows { result.addNamed(row.address, Known(row)) }
            }
        }
        let selected = settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue)
        if let selected { result.addNamed(selected.address, Known(selected, isSelected: true)) }
        let snapshot = networkSnapshot(environment)
        if let snapshot {
            for (index, wallet) in snapshot.wallets.enumerated() {
                if live == .rows([]), wallet.secretSource == .mnemonicEntropy,
                   try !environment.keystore.checkKey(for: KeystoreTag.entropyTagForAddress(wallet.existingSoraAddress)) {
                    result.legacyRemovedAddresses.insert(wallet.existingSoraAddress)
                }
                let account = snapshot.accounts.first { $0.walletId == wallet.id && $0.networkId == .sora2 }
                result.addNamed(wallet.existingSoraAddress, Known(
                    // A 32-byte public key does not distinguish Sr25519 from
                    // Ed25519. Older snapshots did not record this metadata;
                    // retained rows or proven keys must supply it instead.
                    publicKey: account?.publicKey, cryptoType: snapshot.soraCryptoTypes?[wallet.existingSoraAddress],
                    networkType: try? SS58AddressFactory().type(fromAddress: wallet.existingSoraAddress).uint16Value,
                    username: wallet.displayName, order: Int16(clamping: index),
                    isSelected: snapshot.selectedWalletId == wallet.id))
                // A readable empty database can reflect an intentional legacy
                // removal. Missing signing keys then must not resurrect that
                // row. A lost/unreadable database has no such evidence: retain
                // the complete snapshot inventory, including keyless rows.
                if live != .rows([]) || wallet.secretSource == .watchOnly || wallet.secretSource == .signingUnavailable {
                    result.snapshotRows.insert(wallet.existingSoraAddress)
                }
            }
        }

        let incompleteRows: [WalletStoreAccountScan.Row]?
        switch live {
        case let .incomplete(rows): incompleteRows = rows
        case .unreadable, .missing: incompleteRows = snapshot == nil ? nil : []
        default: incompleteRows = nil
        }
        if let rows = incompleteRows {
            // A damaged or missing store cannot reveal identities on lost pages,
            // especially watch-only wallets absent from Keychain. The current
            // validated snapshot is a full inventory; older database backups
            // only fill metadata, since they may predate a later wallet import.
            guard let snapshot, !snapshot.wallets.isEmpty,
                  try !hasUnfinishedAccountCommit(environment) else { throw Failure.incompleteInventory }
            let expected = Set(snapshot.wallets.map(\.existingSoraAddress))
            // A retained copy can be newer than the snapshot (for example,
            // after a legacy import and an interrupted bootstrap). Without a
            // removal record, no readable identity may be discarded to fit it.
            guard Set(rows.map(\.address)).isSubset(of: expected),
                  Set(result.named.keys).isSubset(of: expected) else { throw Failure.incompleteInventory }
            for address in expected {
                result.named[address]?.isSelected = address == snapshot.selectedWalletId
            }
            result.requiredAddresses = expected
        }

        let hasPIN = try environment.keystore.checkKey(for: KeystoreTag.pincode.rawValue)
        if result.named.isEmpty, hasPIN, settings.bool(for: setUpAgainChosenKey) != true {
            for (address, known) in setAsideNames(environment) { result.addNamed(address, known) }
        }
        // Existing installation records take precedence over keys retained
        // from unrelated earlier installations.
        if liveFileIsDamaged, result.named.isEmpty, hasPIN,
           settings.bool(for: setUpAgainChosenKey) != true {
            let wallets = try RetainedKeychainWalletDiscovery.inventory(
                keystore: environment.keystore, recoveryGate: environment.proofGate).adoptable
            // Keychain also survives uninstall. A corrupt file cannot prove
            // that an unbound retained key belongs to this installation's PIN.
            // Do not turn those keys into a new, apparently complete inventory.
            let owner = WalletOwnerPIN(keystore: environment.keystore, settings: settings,
                                       recoveryGate: environment.proofGate)
            for wallet in wallets {
                guard try environment.keystore.checkKey(for: wallet.address + WalletOwnerPIN.bindingSuffix) else {
                    throw Failure.incompleteInventory
                }
            }
            for wallet in wallets where try owner.currentPINMayOwn(address: wallet.address) {
                result.addNamed(wallet.address, Known(publicKey: wallet.publicKey, cryptoType: wallet.cryptoType,
                                                      networkType: wallet.networkType))
            }
        }
        return result
    }

    /// The databases retained by earlier startups, newest first.
    private static func retainedDatabaseCopies(_ environment: Environment) -> [URL] {
        let fileManager = environment.fileManager
        let attempts = (try? fileManager.contentsOfDirectory(
            at: environment.safetyURL, includingPropertiesForKeys: [.contentModificationDateKey], options: []
        )) ?? []
        func modified(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        return attempts
            .filter { UUID(uuidString: $0.lastPathComponent) != nil }
            .sorted { modified($0) > modified($1) }
            .map { $0.appendingPathComponent("legacy-store", isDirectory: true)
                .appendingPathComponent(environment.storeName) }
    }

    /// The wallets named by the newest folder an earlier version set aside.
    private static func setAsideNames(_ environment: Environment) -> [String: Known] {
        let fileManager = environment.fileManager
        let folders = (try? fileManager.contentsOfDirectory(
            at: environment.paths.setAsideRootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        for folder in folders.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
            var names: [String: Known] = [:]
            let database = folder.appendingPathComponent("CoreData", isDirectory: true)
                .appendingPathComponent(environment.storeName)
            if case let .rows(rows) = WalletStoreAccountScan.read(storeURL: database, fileManager: fileManager) {
                for row in rows where names[row.address] == nil { names[row.address] = Known(row) }
            }
            if let data = try? Data(contentsOf: folder.appendingPathComponent("wallet-settings.plist")),
               let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let encoded = values[SettingsKey.selectedAccount.rawValue] as? Data,
               let account = try? JSONDecoder().decode(AccountItem.self, from: encoded) {
                if names[account.address] == nil {
                    names[account.address] = Known(account, isSelected: true)
                } else {
                    names[account.address]?.fill(from: Known(account, isSelected: true))
                }
            }
            if !names.isEmpty { return names }
        }
        return [:]
    }

    // MARK: Which accounts come back

    private static func proof(
        for address: String,
        environment: Environment
    ) throws -> RetainedKeychainWallet? {
        do {
            if let wallet = try RetainedKeychainWalletDiscovery.prove(
                address: address, keystore: environment.keystore, recoveryGate: environment.proofGate) {
                return wallet
            }
            if case let .proven(wallet) = try RetainedKeychainWalletDiscovery.proveGlobalEntropy(
                keystore: environment.keystore, recoveryGate: environment.proofGate), wallet.address == address {
                return wallet
            }
            return nil
        } catch let error where error is KeystoreSystemError || error is KeystoreError {
            // A Keychain that cannot be read proves nothing: try again later.
            throw error
        } catch {
            return nil
        }
    }

    private static func restorableAccounts(from inventory: Inventory, environment: Environment) throws -> [AccountItem] {
        let settings = environment.settings
        let readsLiveRows = !inventory.liveRows.isEmpty
        let source = readsLiveRows ? inventory.liveRows : inventory.named
        let ordered = source.keys.sorted { lhs, rhs in
            let left = source[lhs]?.order ?? .max, right = source[rhs]?.order ?? .max
            return left != right ? left < right : lhs < rhs
        }
        let owner = WalletOwnerPIN(keystore: environment.keystore, settings: settings, recoveryGate: environment.proofGate)
        let legacyName = settings.anyValue(for: KeystoreTag.legacyUsername.rawValue) as? String

        var accounts: [AccountItem] = []
        for (index, address) in ordered.enumerated() {
            guard !inventory.legacyRemovedAddresses.contains(address) else { continue }
            guard let known = source[address] else { continue }
            // A row the database still has already belongs to this PIN's
            // wallet, and a saved plan was checked when it was written. Anything
            // else joins only if no owner record objects.
            let isDatabaseRow = readsLiveRows || inventory.salvagedRows.contains(address)
            if !isDatabaseRow, inventory.plannedAccounts == nil, try !owner.currentPINMayOwn(address: address) {
                continue
            }
            let wallet = try proof(for: address, environment: environment)
            if settings.bool(for: "wallet.watchOnly.\(address)") == true {
                // A watch-only declaration and signing material are contradictory
                // authority. Neither is promoted: the row stays out and the keys
                // stay in the Keychain, behind their owner's phrase or owner PIN.
                if try wallet != nil || environment.keystore.hasScopedSigningMaterial(for: address) { continue }
            }
            let publicKey: Data, cryptoType: CryptoType, networkType: SNAddressType
            if let wallet {
                (publicKey, cryptoType, networkType) = (wallet.publicKey, wallet.cryptoType, wallet.networkType)
            } else {
                guard isDatabaseRow || inventory.plannedAccounts != nil || inventory.snapshotRows.contains(address),
                      let rowKey = known.publicKey, let rowCrypto = known.cryptoType,
                      let rowNetwork = known.networkType,
                      (try? SS58AddressFactory().address(fromAccountId: rowKey, type: rowNetwork)) == address else {
                    continue
                }
                (publicKey, cryptoType, networkType) = (rowKey, rowCrypto, rowNetwork)
            }
            let defaultName = index == 0
                ? WalletUX.text("Restored wallet")
                : "\(WalletUX.text("Restored wallet")) \(index + 1)"
            let name = known.username ?? (wallet?.usesGlobalEntropy == true ? legacyName : nil) ?? defaultName
            accounts.append(AccountItem(
                address: address, cryptoType: cryptoType, networkType: networkType, username: name,
                publicKeyData: publicKey,
                settings: known.assets ?? AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
                order: known.order ?? Int16(clamping: index), isSelected: known.isSelected))
        }
        let selected = SelectedWalletSettings.resolveSelection(
            candidates: accounts.map { ($0.address, Int($0.order), $0.isSelected) },
            legacySelectedAddress: settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue)?.identifier)
        let restored = accounts.map {
            AccountItem(address: $0.address, cryptoType: $0.cryptoType, networkType: $0.networkType,
                        username: $0.username, publicKeyData: $0.publicKeyData, settings: $0.settings,
                        order: $0.order, isSelected: $0.address == selected)
        }
        if let plan = inventory.plannedAccounts {
            guard Set(restored.map(\.address)) == Set(plan.map(\.address)),
                  plan.allSatisfy({ expected in
                      restored.contains { actual in
                          actual.address == expected.address && actual.publicKeyData == expected.publicKeyData &&
                              actual.cryptoType == expected.cryptoType && actual.networkType == expected.networkType
                      }
                  }) else { throw Failure.rebuiltDatabaseDiffers }
        }
        if let expected = inventory.requiredAddresses,
           Set(restored.map(\.address)) != expected { throw Failure.rebuiltDatabaseDiffers }
        return restored
    }

    // MARK: Changing files, always moving and never deleting

    private static func savePlan(_ accounts: [AccountItem], environment: Environment) {
        environment.settings.set(value: accounts, for: planKey)
    }

    private static func clearMarker(_ settings: SettingsManagerProtocol) {
        WalletMigrationRecoveryMarker.synchronized {
            guard WalletMigrationRecoveryMarker.capture(settings).required else { return }
            let generation = UUID().uuidString
            WalletMigrationRecoveryMarker.publish(.init(required: false, reason: nil, generation: generation,
                                                        reasonGeneration: generation), to: settings)
        }
    }

    private static func newSetAsideFolder(_ environment: Environment) throws -> URL {
        let fileManager = environment.fileManager
        let root = environment.paths.setAsideRootURL
        let folder = root.appendingPathComponent(
            "\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try WalletPreservedDataProtection.excludeFromBackup(root)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try WalletPreservedDataProtection.excludeFromBackup(folder)
        return folder
    }

    private static func setAside(_ environment: Environment, includingDatabase: Bool, derivedState: Bool,
                                 into existing: URL? = nil) throws {
        let lease = environment.lifecycleCoordinator.acquire()
        defer { lease.release() }
        let fileManager = environment.fileManager
        let folder = try existing ?? newSetAsideFolder(environment)
        var moves: [(source: URL, place: [String])] = []
        if includingDatabase {
            for suffix in ["", "-wal", "-shm", "-journal"] {
                moves.append((URL(fileURLWithPath: environment.paths.storeURL.path + suffix),
                              ["CoreData", environment.storeName + suffix]))
            }
        }
        if derivedState {
            moves.append((environment.safetyURL, ["CoreData", "WalletMigrationSafety"]))
            for name in ["WalletNetworks", "WalletAccountCommits"] {
                moves.append((environment.soraURL.appendingPathComponent(name, isDirectory: true), [name]))
            }
            // This repair runs only after a stopped return could not finish:
            // its plan must not stop every later launch too.
            moves.append((environment.paths.setAsideRootURL.appendingPathComponent(WalletPreservedGeneration.returnName),
                          [WalletPreservedGeneration.returnName]))
        }
        let records = environment.soraURL.appendingPathComponent(PendingTransactionRecords.directoryName, isDirectory: true)
        let recordsAreUnreadable = derivedState && !PendingTransactionRecords.isReadable(
            baseURL: environment.paths.applicationSupportURL, fileManager: fileManager)
        if recordsAreUnreadable { moves.append((records, [PendingTransactionRecords.directoryName])) }

        for move in moves where WalletPreservedGeneration.exists(move.source) {
            let destination = move.place.reduce(folder) { $0.appendingPathComponent($1) }
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: move.source, to: destination)
        }
        // A store created earlier in this process keeps the records' old path.
        // An empty folder there is a valid "no unfinished transactions" state.
        if recordsAreUnreadable { try? fileManager.createDirectory(at: records, withIntermediateDirectories: true) }
    }

    /// Written and checked aside first, so the only moves left are renames.
    /// A stop at any point is finished by the next launch from the saved plan.
    private static func publish(_ accounts: [AccountItem], environment: Environment) throws {
        let fileManager = environment.fileManager
        let settings = environment.settings
        savePlan(accounts, environment: environment)
        let folder = try newSetAsideFolder(environment)
        var beganPreservingOriginals = false
        defer {
            // A failed staging write (including a full disk) must not leave a
            // new partial replacement on every launch. Until the first live
            // move, this directory contains only this attempt's generated data.
            // Once preservation begins, retain it even if a later move fails.
            if !beganPreservingOriginals { try? fileManager.removeItem(at: folder) }
        }

        let stagedDirectory = folder.appendingPathComponent("rebuilt", isDirectory: true)
        try fileManager.createDirectory(at: stagedDirectory, withIntermediateDirectories: true)
        let staged = stagedDirectory.appendingPathComponent(environment.storeName)
        try environment.databaseWriter.writeRepairedStore(accounts: accounts, at: staged)
        guard case let .rows(written) = WalletStoreAccountScan.read(storeURL: staged, fileManager: fileManager),
              written.count == accounts.count,
              accounts.allSatisfy({ expected in
                  written.contains { actual in
                      actual.address == expected.address && actual.publicKey == expected.publicKeyData &&
                          actual.cryptoType == Int(expected.cryptoType.rawValue) &&
                          actual.networkType == Int(expected.networkType) && actual.isSelected == expected.isSelected
                  }
              }) else {
            throw Failure.rebuiltDatabaseDiffers
        }

        var preserved: [String: Any] = [:]
        for key in WalletLocalStateSetAside.walletSettingKeys(in: settings) where key != planKey {
            if let value = settings.anyValue(for: key),
               PropertyListSerialization.propertyList(value, isValidFor: .binary) {
                preserved[key] = value
            }
        }
        let plist = try PropertyListSerialization.data(fromPropertyList: preserved, format: .binary, options: 0)
        try plist.write(to: folder.appendingPathComponent("wallet-settings.plist"), options: [.atomic])

        beganPreservingOriginals = true
        try setAside(environment, includingDatabase: true, derivedState: true, into: folder)

        let lease = environment.lifecycleCoordinator.acquire()
        defer { lease.release() }
        try fileManager.createDirectory(at: environment.paths.storeURL.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm", "-journal"] {
            let source = URL(fileURLWithPath: staged.path + suffix)
            if WalletPreservedGeneration.exists(source) {
                try fileManager.moveItem(at: source, to: URL(fileURLWithPath: environment.paths.storeURL.path + suffix))
            }
        }
        if let selected = accounts.first(where: \.isSelected) {
            settings.set(value: selected, for: SettingsKey.selectedAccount.rawValue)
        }
        // A watch-only flag only stays with the row it describes. Rebuilt from
        // the new rows at this launch's network bootstrap.
        let kept = Set(accounts.map(\.address))
        for key in settings.allKeys() where key.hasPrefix("wallet.watchOnly.") {
            let address = String(key.dropFirst("wallet.watchOnly.".count))
            if !kept.contains(address) || !(settings.anyValue(for: key) is Bool) {
                settings.removeValue(for: key)
            }
        }
        settings.removeValue(for: SettingsKey.walletNetworkStoreVersion.rawValue)
        settings.removeValue(for: SettingsKey.walletStartupDiagnostic.rawValue)
        clearMarker(settings)
        settings.removeValue(for: planKey)
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
            WalletDatabaseSelfRepair.planKey,
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
         SettingsKey.walletStartupDiagnostic.rawValue, KeystoreTag.legacyUsername.rawValue,
         WalletDatabaseSelfRepair.planKey].contains(key) ||
            key.hasPrefix("wallet.watchOnly.")
    }

    static func syncDirectory(_ url: URL) throws {
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw Failure.interrupted }
        defer { Darwin.close(fd) }
        guard Darwin.fsync(fd) == 0 else { throw Failure.interrupted }
    }
}
