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
import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCrypto
import SSFUtils

/// What the user chose on the recovery screen after the blocking state was
/// set aside. Both continue in the ordinary onboarding flows.
enum WalletRecoveryStartOverIntent {
    case createWallet
    case restoreWallet
}

/// Signing material still held in this app's Keychain for a wallet whose
/// database record is gone (after a reinstall, or a lost wallet database).
/// The address in the Keychain tag is re-derived from the material before the
/// wallet is offered, so restoring it needs no recovery phrase.
struct WalletRecoveryKeychainWallet: Equatable {
    enum Source: Equatable {
        case scopedEntropy
        case scopedSeed
        case legacyEntropy
    }

    let address: String
    let cryptoType: CryptoType
    let derivationPath: String
    let source: Source
    let displayName: String
}

enum WalletRecoveryKeychainScanner {
    static let defaultDisplayName = "SORA wallet"

    /// Display names outlive the database in the selected-account setting and
    /// the network snapshot. Both are optional hints for naming a restore.
    static func retainedDisplayNames(settings: SettingsManagerProtocol) -> [String: String] {
        var names: [String: String] = [:]
        // Opening the store creates its directory; only read one that exists.
        let snapshotDirectory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("SORA/WalletNetworks", isDirectory: true)
        if let snapshotDirectory, FileManager.default.fileExists(atPath: snapshotDirectory.path),
           let snapshot = try? WalletNetworkStore().load() {
            for wallet in snapshot.wallets where !wallet.displayName.isEmpty {
                names[wallet.existingSoraAddress] = wallet.displayName
            }
        }
        if let selected = retainedSelectedAccount(settings: settings), !selected.username.isEmpty {
            names[selected.address] = selected.username
        }
        return names
    }

    /// The Keychain is the only record of a wallet when the database is gone,
    /// or when an interrupted restore left a new database with no accounts.
    /// A store this model cannot open read-only is not treated as empty.
    static func walletDatabaseHasNoAccounts(storeURL: URL = UserStorageParams.storageURL) -> Bool {
        guard (try? FileManager.default.attributesOfItem(atPath: storeURL.path)) != nil else { return true }
        let name = UserStorageParams.modelVersion.rawValue
        let directory = UserStorageParams.modelDirectory
        guard let modelURL = Bundle.main.url(forResource: name, withExtension: "omo", subdirectory: directory)
                ?? Bundle.main.url(forResource: name, withExtension: "mom", subdirectory: directory),
              let model = NSManagedObjectModel(contentsOf: modelURL)
        else { return false }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        guard let store = try? coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [NSReadOnlyPersistentStoreOption: true, NSSQLitePragmasOption: ["query_only": "ON"]]
        ) else { return false }
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        var count = -1
        context.performAndWait {
            count = (try? context.count(for: NSFetchRequest<NSManagedObject>(entityName: "CDAccountItem"))) ?? -1
        }
        return count == 0
    }

    static func retainedSelectedAccount(settings: SettingsManagerProtocol) -> AccountItem? {
        settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue)
    }

    /// Returns only wallets whose live Keychain material re-derives the exact
    /// address it is stored under. Retired records are never considered.
    static func wallets(
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        displayNames: [String: String] = [:]
    ) throws -> [WalletRecoveryKeychainWallet] {
        let identifiers = Set(try keystore.allKeyIdentifiers().filter {
            !$0.hasPrefix(WalletRecoveryFreshStart.retiredTagPrefix)
        })
        var addresses = Set<String>()
        for identifier in identifiers {
            for suffix in ["-entropy", "-seed"] where identifier.hasSuffix(suffix) {
                addresses.insert(String(identifier.dropLast(suffix.count)))
            }
        }
        var wallets: [WalletRecoveryKeychainWallet] = addresses.sorted().compactMap { address in
            try? scopedWallet(
                address: address,
                identifiers: identifiers,
                keystore: keystore,
                displayName: displayNames[address]
            )
        }
        if identifiers.contains(KeystoreTag.legacyEntropy.rawValue),
           let legacy = try? legacyWallet(keystore: keystore, settings: settings, displayNames: displayNames),
           !wallets.contains(where: { $0.address == legacy.address }) {
            wallets.append(legacy)
        }
        return wallets
    }

    private static func scopedWallet(
        address: String,
        identifiers: Set<String>,
        keystore: KeystoreProtocol,
        displayName: String?
    ) throws -> WalletRecoveryKeychainWallet? {
        let addressType = try SS58AddressFactory().type(fromAddress: address).uint16Value
        guard addressType == Chain.sora.addressType() else { return nil }

        var derivationPath = ""
        if identifiers.contains(KeystoreTag.deriviationTagForAddress(address)) {
            let data = try keystore.fetchKey(for: KeystoreTag.deriviationTagForAddress(address))
            guard let path = String(data: data, encoding: .utf8) else { return nil }
            derivationPath = path
        }
        let junction = derivationPath.isEmpty
            ? nil
            : try SubstrateJunctionFactory().parse(path: derivationPath)

        let source: WalletRecoveryKeychainWallet.Source
        var seed: Data
        if identifiers.contains(KeystoreTag.entropyTagForAddress(address)) {
            seed = try miniSeed(
                entropy: keystore.fetchKey(for: KeystoreTag.entropyTagForAddress(address)),
                password: junction?.password ?? ""
            )
            source = .scopedEntropy
        } else {
            seed = try keystore.fetchKey(for: KeystoreTag.seedTagForAddress(address))
            source = .scopedSeed
        }
        defer { seed.resetBytes(in: seed.startIndex ..< seed.endIndex) }

        guard let cryptoType = matchingCryptoType(
            address: address,
            addressType: addressType,
            seed: seed,
            chaincodes: junction?.chaincodes ?? []
        ) else { return nil }

        return WalletRecoveryKeychainWallet(
            address: address,
            cryptoType: cryptoType,
            derivationPath: derivationPath,
            source: source,
            displayName: displayName ?? defaultDisplayName
        )
    }

    /// Pre-account-model entropy backs the default sr25519 SORA account, as in
    /// the explicit legacy upgrade, and only once any unscoped Iroha key beside
    /// it is proven to belong to the same entropy.
    private static func legacyWallet(
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        displayNames: [String: String]
    ) throws -> WalletRecoveryKeychainWallet? {
        var entropy = try keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue)
        defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
        guard !entropy.isEmpty else { return nil }
        try keystore.verifyLegacyIrohaKeyIfPresent(entropy: entropy)

        var seed = try miniSeed(entropy: entropy, password: "")
        defer { seed.resetBytes(in: seed.startIndex ..< seed.endIndex) }
        let publicKey = try SR25519KeypairFactory()
            .createKeypairFromSeed(seed, chaincodeList: [])
            .publicKey()
            .rawData()
        let address = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: Chain.sora.addressType()
        )
        let legacyName = try? LegacyWalletUpgradeDisplayNameResolver.resolve(
            settings: settings,
            keystore: keystore
        )
        return WalletRecoveryKeychainWallet(
            address: address,
            cryptoType: .sr25519,
            derivationPath: "",
            source: .legacyEntropy,
            displayName: displayNames[address] ?? legacyName.flatMap { $0.isEmpty ? nil : $0 } ?? defaultDisplayName
        )
    }

    private static func miniSeed(entropy: Data, password: String) throws -> Data {
        var entropy = entropy
        defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
        var phrase = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy).toString()
        defer { phrase.removeAll(keepingCapacity: false) }
        return try SeedFactory().deriveSeed(from: phrase, password: password).seed.miniSeed
    }

    /// Same derivation as account creation and seed import in
    /// `AccountOperationFactory`; the first crypto type that reproduces the
    /// stored address is the wallet's.
    private static func matchingCryptoType(
        address: String,
        addressType: UInt16,
        seed: Data,
        chaincodes: [Chaincode]
    ) -> CryptoType? {
        let factories: [(CryptoType, KeypairFactoryProtocol)] = [
            (.sr25519, SR25519KeypairFactory()),
            (.ed25519, Ed25519KeypairFactory()),
            (.ecdsa, EcdsaKeypairFactory()),
        ]
        return factories.first { candidate in
            guard let publicKey = try? candidate.1
                .createKeypairFromSeed(seed, chaincodeList: chaincodes)
                .publicKey()
                .rawData()
            else { return false }
            return (try? SS58AddressFactory().address(fromAccountId: publicKey, type: addressType)) == address
        }?.0
    }
}

enum WalletRecoveryFreshStartError: Error {
    case retiredRecordConflict
}

/// Sets aside the wallet state that stopped startup so the ordinary create,
/// import and restore flows can run again. Nothing is deleted: settings are
/// copied and files are moved into a dated archive under Application Support.
/// When the user starts over, every live Keychain wallet record and the PIN are
/// copied to retired tags (verified) before their live tags are removed.
/// Retired records are never offered by the Keychain restore, so a PIN set
/// after starting over cannot unlock a wallet that PIN never protected.
enum WalletRecoveryFreshStart {
    static let retiredTagPrefix = "retired."
    static let retiredTagSuffix = ".retired"
    static let archivesSettingsKey = "walletRecovery.archives"

    struct Outcome: Equatable {
        let archiveId: String
        let archiveURL: URL
        let movedItems: [String]
        let retiredKeychainRecords: Int
    }

    static func isWalletMaterialTag(_ tag: String) -> Bool {
        guard !tag.hasPrefix(retiredTagPrefix) else { return false }
        return [KeystoreTag.legacyEntropy.rawValue, KeystoreTag.legacyUsername.rawValue, "privateKey"].contains(tag) ||
            ["-secretKey", "-entropy", "-deriv", "-seed"].contains { tag.hasSuffix($0) }
    }

    static func retiredTag(for tag: String, archiveId: String) -> String {
        retiredTagPrefix + archiveId + "." + tag + retiredTagSuffix
    }

    /// The production entry point used by the recovery screen.
    static func setAsideInstalledState(retiringKeychainMaterial: Bool) throws -> Outcome {
        let fileManager = FileManager.default
        let outcome = try setAside(
            retiringKeychainMaterial: retiringKeychainMaterial,
            keystore: Keychain(),
            settings: SettingsManager.shared,
            fileManager: fileManager,
            databaseDirectoryURL: UserStorageParams.storageDirectoryURL,
            applicationSupportURL: fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ),
            closeDatabase: {
                // A moved SQLite file stays open under its new path; detach the
                // shared store so the next access creates a fresh one in place.
                try? UserDataStorageFacade.shared.databaseService.close()
            }
        )
        SelectedWalletSettings.shared.commitInternalValue(nil)
        return outcome
    }

    static func setAside(
        retiringKeychainMaterial: Bool,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        fileManager: FileManager,
        databaseDirectoryURL: URL,
        applicationSupportURL: URL,
        now: Date = Date(),
        closeDatabase: () -> Void
    ) throws -> Outcome {
        closeDatabase()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let archiveId = formatter.string(from: now) + "-" + UUID().uuidString.prefix(8).lowercased()
        let soraSupportURL = applicationSupportURL.appendingPathComponent("SORA", isDirectory: true)
        var archiveURL = soraSupportURL
            .appendingPathComponent("WalletRecoveryArchive", isDirectory: true)
            .appendingPathComponent(archiveId, isDirectory: true)
        try fileManager.createDirectory(at: archiveURL, withIntermediateDirectories: true)
        var backupValues = URLResourceValues()
        backupValues.isExcludedFromBackup = true
        try? archiveURL.setResourceValues(backupValues)

        // Settings first: they hold the only record of the previous selection.
        var settingsCopy: [String: Any] = [:]
        for key in settings.allKeys() {
            if let value = settings.anyValue(for: key) { settingsCopy[key] = value }
        }
        let settingsData: Data
        if let full = try? PropertyListSerialization.data(fromPropertyList: settingsCopy, format: .binary, options: 0) {
            settingsData = full
        } else {
            // A value that is not a property list still leaves its key on record.
            settingsData = try PropertyListSerialization.data(
                fromPropertyList: settingsCopy.keys.sorted(), format: .binary, options: 0
            )
        }
        try settingsData.write(to: archiveURL.appendingPathComponent("settings.plist"), options: .atomic)

        // Wallet records before the PIN, so a failure part way leaves the PIN
        // protecting whatever is still live.
        var retiredCount = 0
        if retiringKeychainMaterial {
            let identifiers = try keystore.allKeyIdentifiers()
            let walletTags = identifiers.filter(isWalletMaterialTag)
            let pinTags = identifiers.filter {
                $0 == KeystoreTag.pincode.rawValue || $0 == PinAttemptRecord.keystoreTag
            }
            for tag in walletTags + pinTags {
                try retire(tag, archiveId: archiveId, keystore: keystore)
                retiredCount += 1
            }
        }

        // The database directory (store, sidecars, migration safety copies),
        // the network snapshot and the account commit journals.
        let items: [(String, URL)] = [
            ("CoreData", databaseDirectoryURL),
            ("WalletNetworks", soraSupportURL.appendingPathComponent("WalletNetworks", isDirectory: true)),
            ("WalletAccountCommits", soraSupportURL.appendingPathComponent("WalletAccountCommits", isDirectory: true)),
        ]
        var moved: [String] = []
        for (name, url) in items where (try? fileManager.attributesOfItem(atPath: url.path)) != nil {
            try fileManager.moveItem(at: url, to: archiveURL.appendingPathComponent(name, isDirectory: true))
            moved.append(name)
        }

        // Starting over leaves settings as a fresh install would. A Keychain
        // restore keeps identity history and the PIN attempt counters.
        var removedKeys: Set<String> = [
            SettingsKey.selectedAccount.rawValue,
            SettingsKey.walletNetworkStoreVersion.rawValue,
            SettingsKey.walletStartupDiagnostic.rawValue,
        ]
        if retiringKeychainMaterial {
            removedKeys.formUnion([
                SettingsKey.decentralizedId.rawValue,
                SettingsKey.publicKeyId.rawValue,
                SettingsKey.hasMigrated.rawValue,
                SettingsKey.migratedAccountsV1.rawValue,
                SettingsKey.failInputPinCount.rawValue,
                SettingsKey.inputBlockDate.rawValue,
                KeystoreTag.legacyUsername.rawValue,
            ])
        }
        for key in settings.allKeys() where removedKeys.contains(key) ||
            (retiringKeychainMaterial && key.hasPrefix("wallet.watchOnly.")) {
            settings.removeValue(for: key)
        }
        WalletMigrationRecoveryMarker.synchronized {
            let generation = UUID().uuidString
            WalletMigrationRecoveryMarker.publish(
                .init(required: false, reason: nil, generation: generation, reasonGeneration: generation),
                to: settings
            )
        }
        let archives = (settings.anyValue(for: archivesSettingsKey) as? [String] ?? []) + [archiveId]
        settings.set(anyValue: archives, for: archivesSettingsKey)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let manifest: [String: Any] = [
            "archiveId": archiveId,
            "createdAt": ISO8601DateFormatter().string(from: now),
            "mode": retiringKeychainMaterial ? "start_over" : "restore_from_keychain",
            "app": "\(version) (\(build))",
            "movedItems": moved,
            "retiredKeychainRecords": retiredCount,
            "settingsKeysCopied": settingsCopy.count,
        ]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: archiveURL.appendingPathComponent("manifest.json"), options: .atomic)

        return Outcome(
            archiveId: archiveId,
            archiveURL: archiveURL,
            movedItems: moved,
            retiredKeychainRecords: retiredCount
        )
    }

    private static func retire(_ tag: String, archiveId: String, keystore: KeystoreProtocol) throws {
        var value = try keystore.fetchKey(for: tag)
        defer { value.resetBytes(in: value.startIndex ..< value.endIndex) }
        let retired = retiredTag(for: tag, archiveId: archiveId)
        if try !keystore.checkKey(for: retired) {
            try keystore.addKey(value, with: retired)
        }
        var copy = try keystore.fetchKey(for: retired)
        defer { copy.resetBytes(in: copy.startIndex ..< copy.endIndex) }
        guard copy == value else { throw WalletRecoveryFreshStartError.retiredRecordConflict }
        try keystore.deleteKey(for: tag)
    }
}

/// Restores proven Keychain wallets one at a time through the ordinary import
/// path, so the database row, network snapshot and selection are written by
/// the same journaled code as a user import. Identical Keychain records are
/// reused rather than rewritten (see `PreparedAccount.persist(to:)`).
final class WalletRecoveryKeychainRestorer {
    private final class ImportOutput: AccountImportInteractorOutputProtocol {
        var onError: ((Error) -> Void)?

        func didReceiveAccountImport(metadata _: AccountImportMetadata) {}
        func didCompleteAccountImport() {}
        func didReceiveAccountImport(error: Error) { onError?(error) }
        func didSuggestKeystore(text _: String, preferredInfo _: AccountImportPreferredInfo?) {}
    }

    private let keystore: KeystoreProtocol
    private let output = ImportOutput()
    private var interactor: AccountImportInteractor?

    init(keystore: KeystoreProtocol = Keychain()) {
        self.keystore = keystore
    }

    /// Each import selects its account, so the previously selected wallet is
    /// restored last and stays selected.
    func restore(
        _ wallets: [WalletRecoveryKeychainWallet],
        selectedAddress: String?,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let ordered = wallets.filter { $0.address != selectedAddress } +
            wallets.filter { $0.address == selectedAddress }
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()
        let interactor = AccountImportInteractor(
            accountOperationFactory: AccountOperationFactory(keystore: keystore),
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationManager: OperationManagerFacade.sharedManager,
            settings: SelectedWalletSettings.shared,
            keystoreImportService: KeystoreImportService(logger: Logger.shared),
            eventCenter: EventCenter.shared,
            allowedMnemonicWordCounts: WalletMnemonicWordPolicy.retainedSoraWordCounts
        )
        interactor.presenter = output
        self.interactor = interactor
        restoreNext(ordered[...], restored: 0, completion: completion)
    }

    private func restoreNext(
        _ remaining: ArraySlice<WalletRecoveryKeychainWallet>,
        restored: Int,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        guard let wallet = remaining.first, let interactor else {
            self.interactor = nil
            completion(.success(restored))
            return
        }
        // The interactor reports a failure both to its output and to the
        // completion; act on the first report only.
        var finished = false
        let finish: (Result<AccountItem, Error>) -> Void = { [weak self] result in
            guard !finished else { return }
            finished = true
            switch result {
            case .success:
                self?.restoreNext(remaining.dropFirst(), restored: restored + 1, completion: completion)
            case let .failure(error):
                self?.interactor = nil
                completion(.failure(error))
            }
        }
        output.onError = { finish(.failure($0)) }

        do {
            switch wallet.source {
            case .scopedEntropy, .legacyEntropy:
                let tag = wallet.source == .legacyEntropy
                    ? KeystoreTag.legacyEntropy.rawValue
                    : KeystoreTag.entropyTagForAddress(wallet.address)
                var entropy = try keystore.fetchKey(for: tag)
                defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
                var phrase = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy).toString()
                defer { phrase.removeAll(keepingCapacity: false) }
                let request = AccountImportMnemonicRequest(
                    mnemonic: phrase,
                    username: wallet.displayName,
                    networkType: .sora,
                    derivationPath: wallet.derivationPath,
                    cryptoType: wallet.cryptoType
                )
                interactor.importAccountWithMnemonic(request: request) { result in
                    finish(result ?? .failure(BaseOperationError.parentOperationCancelled))
                }
            case .scopedSeed:
                var seed = try keystore.fetchKey(for: KeystoreTag.seedTagForAddress(wallet.address))
                defer { seed.resetBytes(in: seed.startIndex ..< seed.endIndex) }
                let request = AccountImportSeedRequest(
                    seed: seed.toHex(),
                    username: wallet.displayName,
                    networkType: .sora,
                    derivationPath: wallet.derivationPath,
                    cryptoType: wallet.cryptoType
                )
                interactor.importAccountWithSeed(request: request) { result in
                    finish(result ?? .failure(BaseOperationError.parentOperationCancelled))
                }
            }
        } catch {
            finish(.failure(error))
        }
    }
}
