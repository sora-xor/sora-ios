// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CoreData
import CryptoKit
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCloudStorage
import SSFCrypto
import SSFUtils
import SoraFoundation
import UIKit
import XCTest
@testable import SoraPassport

// MARK: - Fixtures

/// A Keychain that behaves like the real one for `addKey` (duplicates are
/// rejected) and records every write the code under test makes. Fixtures are
/// written through `base`, so they are not recorded.
private final class AddOnlyRecordingKeychain: KeystoreProtocol {
    let base = InMemoryKeychain()
    private(set) var added: [String] = []
    private(set) var updated: [String] = []
    private(set) var deleted: [String] = []

    func addKey(_ key: Data, with identifier: String) throws {
        guard try !base.checkKey(for: identifier) else { throw KeystoreError.duplicatedItem }
        try base.addKey(key, with: identifier)
        added.append(identifier)
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
        try Dictionary(uniqueKeysWithValues: base.allKeyIdentifiers().map { ($0, try base.fetchKey(for: $0)) })
    }

    var changedExistingItems: Bool { !updated.isEmpty || !deleted.isEmpty }
}

private final class KeySafetySecurityLayerStub: SecurityLayerInteractorInputProtocol {
    func setup() {}
}

private final class KeySafetyRootPresenterSpy: RootInteractorOutputProtocol {
    enum Decision: Equatable { case onboarding, legacyWalletUpgrade, localAuthentication, broken, pincodeSetup, welcomeBack }
    var decisions: [Decision] = []
    func didDecideOnboarding() { decisions.append(.onboarding) }
    func didDecideLegacyWalletUpgrade() { decisions.append(.legacyWalletUpgrade) }
    func didDecideLocalAuthentication() { decisions.append(.localAuthentication) }
    func didDecideBroken() { decisions.append(.broken) }
    func didDecidePincodeSetup() { decisions.append(.pincodeSetup) }
    func didDecideWelcomeBack() { decisions.append(.welcomeBack) }
}

/// Historical writers, copied from released code so fixtures hold exactly the
/// items those releases wrote.
private enum HistoricalWriter {
    /// SORA 1.5.1 `IdentityCreationOperation.main()`:
    /// `saveKey(keypair.privateKey().rawData(), with: "privateKey")` and
    /// `saveKey(mnemonic.entropy(), with: "seedEntropy")`, from
    /// `IRKeypairFacade` (Iroha ed25519, 15 words). The display name lived in
    /// settings under `userName`.
    static func version1(phrase: String, keystore: KeystoreProtocol) throws -> Data {
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: phrase)
        let keypair = try IRKeypairFacade().deriveKeypair(from: phrase, password: "")
        try keystore.saveKey(keypair.privateKey().rawData(), with: "privateKey")
        try keystore.saveKey(mnemonic.entropy(), with: "seedEntropy")
        return mnemonic.entropy()
    }

    /// 2.x (`e52beedd`) and App Store 3.8.6 (`354f176c`)
    /// `AccountOperationFactory.newAccountOperation(request:mnemonic:)`: derive
    /// with `SeedFactory` and the keypair factory, then `saveSecretKey`,
    /// `saveEntropy`, `saveDeriviation` (non-empty path only), `saveSeed`.
    @discardableResult
    static func phraseImport(
        _ phrase: String, path: String = "", cryptoType: CryptoType = .sr25519,
        username: String = "Released wallet", order: Int16 = 0, isSelected: Bool = true,
        keystore: KeystoreProtocol
    ) throws -> AccountItem {
        let junction = path.isEmpty ? nil : try SubstrateJunctionFactory().parse(path: path)
        let result = try SeedFactory().deriveSeed(from: phrase, password: junction?.password ?? "")
        let chaincodes = junction?.chaincodes ?? []
        let keypair = try keypairFactory(cryptoType).createKeypairFromSeed(result.seed.miniSeed, chaincodeList: chaincodes)
        let address = try SS58AddressFactory().address(fromAccountId: keypair.publicKey().rawData(),
                                                       type: Chain.sora.addressType())
        let secretKey: Data
        switch cryptoType {
        case .sr25519: secretKey = keypair.privateKey().rawData()
        case .ed25519: secretKey = try Ed25519KeypairFactory().deriveChildSeedFromParent(result.seed.miniSeed, chaincodeList: chaincodes)
        case .ecdsa: secretKey = try EcdsaKeypairFactory().deriveChildSeedFromParent(result.seed.miniSeed, chaincodeList: chaincodes)
        }
        try keystore.saveSecretKey(secretKey, address: address)
        try keystore.saveEntropy(result.mnemonic.entropy(), address: address)
        if !path.isEmpty { try keystore.saveDeriviation(path, address: address) }
        try keystore.saveSeed(result.seed.miniSeed, address: address)
        return AccountItem(address: address, cryptoType: cryptoType, networkType: Chain.sora.addressType(),
                           username: username, publicKeyData: keypair.publicKey().rawData(),
                           settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
                           order: order, isSelected: isSelected)
    }

    /// Same releases, `newAccountOperation(request: AccountImportSeedRequest)`:
    /// `saveSecretKey`, `saveDeriviation` (non-empty path), `saveSeed`.
    @discardableResult
    static func seedImport(
        _ seed: Data, cryptoType: CryptoType, username: String = "Seed wallet", order: Int16 = 0,
        keystore: KeystoreProtocol
    ) throws -> AccountItem {
        let keypair = try keypairFactory(cryptoType).createKeypairFromSeed(seed, chaincodeList: [])
        let address = try SS58AddressFactory().address(fromAccountId: keypair.publicKey().rawData(),
                                                       type: Chain.sora.addressType())
        let secretKey: Data
        switch cryptoType {
        case .sr25519: secretKey = keypair.privateKey().rawData()
        case .ed25519: secretKey = try Ed25519KeypairFactory().deriveChildSeedFromParent(seed.miniSeed, chaincodeList: [])
        case .ecdsa: secretKey = try EcdsaKeypairFactory().deriveChildSeedFromParent(seed.miniSeed, chaincodeList: [])
        }
        try keystore.saveSecretKey(secretKey, address: address)
        try keystore.saveSeed(seed, address: address)
        return AccountItem(address: address, cryptoType: cryptoType, networkType: Chain.sora.addressType(),
                           username: username, publicKeyData: keypair.publicKey().rawData(),
                           settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
                           order: order, isSelected: true)
    }

    /// Same releases, `newAccountOperation(request: AccountImportKeystoreRequest)`:
    /// only `saveSecretKey(keystore.secretKeyData)`.
    @discardableResult
    static func jsonImport(secret: Data, publicKey: Data, cryptoType: CryptoType,
                           keystore: KeystoreProtocol) throws -> AccountItem {
        let address = try SS58AddressFactory().address(fromAccountId: publicKey, type: Chain.sora.addressType())
        try keystore.saveSecretKey(secret, address: address)
        return AccountItem(address: address, cryptoType: cryptoType, networkType: Chain.sora.addressType(),
                           username: "JSON wallet", publicKeyData: publicKey,
                           settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
                           order: 0, isSelected: true)
    }

    /// App Store 3.8.6 removing a non-final account: `logoutAndClean()` →
    /// `cleanKeystore(leavingPin: true)` → `deleteEntropy(for:)` only.
    static func appStore386RemoveAccount(_ address: String, keystore: KeystoreProtocol) throws {
        try keystore.deleteKeyIfExists(for: KeystoreTag.entropyTagForAddress(address))
    }

    static func keypairFactory(_ cryptoType: CryptoType) -> KeypairFactoryProtocol {
        switch cryptoType {
        case .sr25519: return SR25519KeypairFactory()
        case .ed25519: return Ed25519KeypairFactory()
        case .ecdsa: return EcdsaKeypairFactory()
        }
    }
}

/// App Store SORA 3.8.6 (`354f176c`) launch logic, reproduced over this data.
private enum AppStore386Launch {
    struct Outcome {
        let selected: AccountItem?
        let settingsWiped: Bool
    }

    /// `SelectedWalletSettings.performSetup` (first row with `isSelected`),
    /// then `InconsistentStateMigrator.migrate()` (selected account without
    /// `-secretKey` → `settings.removeAll()`), then
    /// `RootInteractor.decideModuleSynchroniously()` (no selection → delete
    /// `pincode`; selection → delete `seedEntropy`).
    static func run(storeURL: URL, keystore: KeystoreProtocol, settings: SettingsManagerProtocol) throws -> Outcome {
        let selected = try KeySafetyStore.rows(at: storeURL).first(where: \.isSelected)
        var wiped = false
        if let selected, try !keystore.checkKey(for: KeystoreTag.secretKeyTagForAddress(selected.address)) {
            settings.removeAll()
            wiped = true
        }
        if selected == nil {
            try keystore.deleteKeyIfExists(for: KeystoreTag.pincode.rawValue)
        } else {
            try? keystore.deleteKeyIfExists(for: KeystoreTag.legacyEntropy.rawValue)
        }
        return Outcome(selected: selected, settingsWiped: wiped)
    }

    /// 3.8.6 signs with `<address>-secretKey` only.
    static func canSign(_ account: AccountItem, keystore: KeystoreProtocol) throws -> Bool {
        guard let secret = try keystore.fetchSecretKeyForAddress(account.address) else { return false }
        let payload = Data("App Store 3.8.6 signing".utf8)
        switch account.cryptoType {
        case .sr25519:
            let publicKey = try SNPublicKey(rawData: account.publicKeyData)
            let signature = try SNSigner(keypair: SNKeypair(privateKey: SNPrivateKey(rawData: secret),
                                                            publicKey: publicKey)).sign(payload)
            return SNSignatureVerifier().verify(signature, forOriginalData: payload, using: publicKey)
        case .ed25519, .ecdsa:
            try Sora2SignatureVerifier.verify(signature: Sora2Ed25519SeedSigner.sign(payload, seed: secret),
                                              originalData: payload, secretKey: secret, account: account)
            return true
        }
    }
}

private enum KeySafetyStore {
    static func model(_ version: UserStorageVersion) throws -> NSManagedObjectModel {
        let url = Bundle.main.url(forResource: version.rawValue, withExtension: "omo",
                                  subdirectory: UserStorageParams.modelDirectory)
            ?? Bundle.main.url(forResource: version.rawValue, withExtension: "mom",
                               subdirectory: UserStorageParams.modelDirectory)
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: XCTUnwrap(url)))
    }

    /// Version 1 has no `isSelected` (2.x kept the selection in UserDefaults).
    static func write(_ accounts: [AccountItem], to storeURL: URL, version: UserStorageVersion = .version2) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try model(version))
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                                       at: storeURL, options: nil)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for account in accounts {
                let row = NSEntityDescription.insertNewObject(forEntityName: "CDAccountItem", into: context)
                row.setValue(account.address, forKey: "identifier")
                row.setValue(account.username, forKey: "username")
                row.setValue(account.publicKeyData, forKey: "publicKey")
                row.setValue(account.cryptoType.rawValue, forKey: "cryptoType")
                row.setValue(account.networkType, forKey: "networkType")
                row.setValue(account.order, forKey: "order")
                if version == .version2 { row.setValue(account.isSelected, forKey: "isSelected") }
            }
            try context.save()
        }
        try coordinator.remove(store)
    }

    static func rows(at storeURL: URL) throws -> [AccountItem] {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return [] }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try model(.version2))
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
            at: storeURL, options: [NSReadOnlyPersistentStoreOption: true])
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        var result: Result<[AccountItem], Error>!
        context.performAndWait {
            result = Result {
                let request = NSFetchRequest<CDAccountItem>(entityName: "CDAccountItem")
                return try context.fetch(request).map { try AccountItemMapper().transform(entity: $0) }
                    .sorted { $0.order < $1.order }
            }
        }
        return try result.get()
    }
}

/// One isolated installation: a directory standing in for Documents/CoreData
/// and Application Support, a Keychain and settings.
private final class Installation {
    let directory: URL
    let keychain = AddOnlyRecordingKeychain()
    var settings = InMemorySettingsManager()
    /// One lifecycle coordinator for the in-memory selection, the network
    /// synchronizer and inserts (a lease only works with its own coordinator).
    lazy var coordinator = WalletLifecycleCoordinator(recoveryGate: isolatedGate())

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }

    var storeURL: URL { directory.appendingPathComponent("UserDataModel.sqlite") }

    func gate() -> WalletRecoveryCapabilityGate {
        let storeURL = self.storeURL
        let directory = self.directory
        return WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: storeURL) },
            unresolvedWalletCommitJournal: { try !WalletAccountCommitJournalStore(baseURL: directory).unresolved().isEmpty })
    }

    func isolatedGate() -> WalletRecoveryCapabilityGate {
        WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false },
                                     unresolvedWalletCommitJournal: { false })
    }

    func networkStore() throws -> WalletNetworkStore {
        try WalletNetworkStore(baseURL: directory, recoveryGate: isolatedGate())
    }

    func migrator(gate: WalletRecoveryCapabilityGate? = nil,
                  marker: WalletMigrationRecoveryMarker? = nil,
                  checkpoint: ((UserStorageMigrationCheckpoint) throws -> Void)? = nil,
                  afterCopy: ((URL) throws -> Void)? = nil) throws -> UserStorageMigrator {
        let store = try networkStore()
        return UserStorageMigrator(targetVersion: .version2, storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory, keystore: keychain, settings: settings,
            fileManager: .default, recoveryGate: gate ?? self.gate(), migrationRecoveryMarker: marker,
            checkpoint: checkpoint,
            availableCapacity: { _ in Int64.max }, loadWalletNetworkSnapshot: { try store.load() },
            afterLegacyStoreCopyBeforeVerification: afterCopy)
    }

    /// A copy of this installation (files, Keychain items and settings), as
    /// if the process had been killed at this moment.
    func copy() throws -> Installation {
        let copy = try Installation()
        try FileManager.default.removeItem(at: copy.directory)
        try FileManager.default.copyItem(at: directory, to: copy.directory)
        for (tag, bytes) in try keychain.bytes() { try copy.keychain.base.addKey(bytes, with: tag) }
        for key in settings.allKeys() {
            if let value = settings.anyValue(for: key) { copy.settings.set(anyValue: value, for: key) }
        }
        return copy
    }

    /// The production startup sequence of `SplashInteractor`, against this
    /// installation: journal and startup recovery, database migration, then
    /// the network bootstrap and the scoped-copy backfill.
    ///
    /// - Parameter sweepsHelperFilesFirst: the explicit sweep that
    ///   `SplashInteractor.performStorageMigration` runs first. Tests pass
    ///   false to show that each folder check also copes by itself.
    @discardableResult
    func startup(migration: (() throws -> Void)? = nil,
                 checkpoint: ((UserStorageMigrationCheckpoint) throws -> Void)? = nil,
                 sweepsHelperFilesFirst: Bool = true) throws
        -> WalletStorageStartupOutcome {
        if sweepsHelperFilesFirst {
            WalletInterruptedWriteCleanup.run(storeURL: storeURL, applicationSupportURL: directory)
        }
        let gate = self.gate()
        let coordinator = WalletLifecycleCoordinator(recoveryGate: gate)
        let database = try migrator(gate: gate, checkpoint: checkpoint)
        let directory = self.directory
        let outcome = WalletStorageStartup.run(settings: settings, accountCommitRecovery: {
            _ = try WalletStartupVerificationRecovery.recoverIfNeeded(storeURL: self.storeURL,
                modelDirectory: UserStorageParams.modelDirectory, keystore: self.keychain,
                settings: self.settings, baseURL: directory, lifecycleCoordinator: coordinator)
            _ = try LegacyWalletAccountCommitRecovery.recoverIfNeeded(storeURL: self.storeURL,
                modelDirectory: UserStorageParams.modelDirectory, keystore: self.keychain,
                settings: self.settings, baseURL: directory, lifecycleCoordinator: coordinator,
                recoveryGate: gate)
        }, retryDelay: { _ in }) {
            try migration?()
            try database.migrateAtStartup(lifecycleCoordinator: coordinator, hasUnresolvedAccountCommit: {
                try !WalletAccountCommitJournalStore(baseURL: directory).unresolved().isEmpty
            })
            try WalletStartupDiagnostic.check(.pendingTransactions) {
                try PendingTransactionRecords.requireReadable(baseURL: directory)
            }
        }
        guard outcome == .ready else { return outcome }
        let accounts = try KeySafetyStore.rows(at: storeURL)
        let selected = try SelectedWalletSettings.resolveSelection(accounts: accounts,
            legacySelectedAddress: settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue)?.identifier)
        let store = try WalletNetworkStore(baseURL: directory, recoveryGate: gate)
        let hasSnapshot = try store.load() != nil
        if !(accounts.isEmpty && selected == nil && !hasSnapshot) {
            try WalletNetworkModelMigrator(keystore: keychain, store: store, settings: settings,
                lifecycleCoordinator: coordinator, recoveryGate: gate)
                .migrate(accounts: accounts, selectedAddress: selected?.address)
        }
        SplashInteractor.addScopedCopiesIfNeeded(accounts: accounts, store: store, keystore: keychain,
            lifecycleCoordinator: coordinator, recoveryGate: gate)
        return outcome
    }

    func rootInteractor(
        selected: AccountItem?,
        legacyImporter: AccountImportInteractorInputProtocol? = nil
    ) throws -> RootInteractor {
        let store = try networkStore()
        return RootInteractor(settings: settings, keystore: keychain, migrators: [],
            securityLayerInteractor: KeySafetySecurityLayerStub(), networkAvailabilityLayerInteractor: nil,
            legacyUpgradeSelectedAccount: { selected }, legacyUpgradeSnapshotLoader: { try store.load() },
            legacyUpgradeUnresolvedCommitLoader: { [] },
            legacyUpgradeInteractorFactory: { _, _, _, _ in legacyImporter })
    }

    func rootDecision(selected: AccountItem?) throws -> [KeySafetyRootPresenterSpy.Decision] {
        let root = try rootInteractor(selected: selected)
        let spy = KeySafetyRootPresenterSpy()
        root.presenter = spy
        root.decideModuleSynchroniously()
        return spy.decisions
    }

    /// `SelectedWalletSettings` over an in-memory Core Data stack whose
    /// network synchronizer writes this installation's snapshot.
    func selectedWalletSettings(accounts: [AccountItem] = [],
                                facade: UserDataStorageTestFacade = UserDataStorageTestFacade()) throws
        -> SelectedWalletSettings {
        if !accounts.isEmpty {
            let repository: CoreDataRepository<AccountItem, CDAccountItem> =
                facade.createRepository(mapper: AnyCoreDataMapper(AccountItemMapper()))
            let save = repository.saveOperation({ accounts }, { [] })
            OperationQueue().addOperations([save], waitUntilFinished: true)
            try save.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }
        let gate = isolatedGate()
        let coordinator = self.coordinator
        let store = try networkStore()
        let keychain = self.keychain
        let settings = self.settings
        let journalStore = try WalletAccountCommitJournalStore(baseURL: directory, recoveryGate: gate)
        return SelectedWalletSettings(storageFacade: facade, operationQueue: OperationQueue(),
            legacySettings: settings,
            walletNetworkSynchronizer: { accounts, selected, lease in
                try WalletNetworkModelMigrator(keystore: keychain, store: store, settings: settings,
                    lifecycleCoordinator: coordinator, recoveryGate: gate)
                    .migrate(accounts: accounts, selectedAddress: selected, lifecycleLease: lease)
            },
            walletNetworkSelectionSynchronizer: { accounts, selected, lease in
                try coordinator.withExclusiveAccess(using: lease) {
                    try store.selectWallet(walletId: selected, expectedAccounts: accounts)
                }
            },
            walletAccountCommitJournalStoreFactory: { journalStore },
            lifecycleCoordinator: coordinator, recoveryGate: gate, keystore: keychain)
    }

    /// The ordinary import path: prepare, then journaled insert whose secret
    /// persistence adopts matching retained items.
    func importPhrase(_ phrase: String, path: String = "", cryptoType: CryptoType = .sr25519,
                      into selection: SelectedWalletSettings) throws -> AccountItem {
        let gate = isolatedGate()
        let factory = AccountOperationFactory(keystore: keychain, recoveryGate: gate)
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: phrase)
        let operation = factory.prepareAccountOperation(request: AccountCreationRequest(username: "Imported",
            type: .sora, derivationPath: path, cryptoType: cryptoType), mnemonic: mnemonic)
        operation.start()
        let prepared = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        return try insert(prepared, into: selection, factory: factory)
    }

    func insert(_ prepared: PreparedAccount, into selection: SelectedWalletSettings,
                factory: AccountOperationFactory) throws -> AccountItem {
        let lease = coordinator.acquire()
        let done = expectationSemaphore()
        var outcome: Result<AccountItem, Error> = .failure(AccountCreateError.duplicated)
        selection.performInsertAndSelect(prepared: prepared,
            persistSecrets: { try factory.persistPreparedAccount(prepared) },
            lifecycleLease: lease) { result in
                outcome = result
                done.signal()
            }
        done.wait()
        lease.release()
        return try outcome.get()
    }

    private func expectationSemaphore() -> DispatchSemaphore { DispatchSemaphore(value: 0) }
}

private let phrase12 = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"

private func phrase(entropy byte: UInt8, bytes: Int) throws -> String {
    try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: Data(repeating: byte, count: bytes)).toString()
}

/// A valid 3/6/9-word phrase (App Store 3.8.6 accepted any multiple of three).
private func shortPhrase(words: Int) throws -> String {
    let list = IRMnemonicCreator(language: .english)
    let wordList = try list.mnemonic(fromEntropy: Data(repeating: 0x5a, count: 32)).allWords()
    var base = Array(wordList.prefix(words - 1))
    for candidate in try list.mnemonic(fromEntropy: Data((0..<32).map { UInt8($0 * 7 & 0xff) })).allWords()
        + wordList {
        base.append(candidate)
        if (try? list.mnemonic(fromList: base.joined(separator: " "))) != nil { return base.joined(separator: " ") }
        base.removeLast()
    }
    // Fall back to an exhaustive search over the English list.
    for index in 0..<2048 {
        let candidate = try list.mnemonic(fromEntropy: Data([UInt8(index >> 3), UInt8((index & 7) << 5)]
            + Data(repeating: 0, count: 14))).allWords()[0]
        base.append(candidate)
        if (try? list.mnemonic(fromList: base.joined(separator: " "))) != nil { return base.joined(separator: " ") }
        base.removeLast()
    }
    throw WalletNetworkMigrationError.invalidMnemonic
}

// MARK: - Tests

final class WalletKeySafetyTests: XCTestCase {

    // MARK: §0.2 retryable startup markers

    func testRetryableMarkerPredicateCoversEveryFixedCode() throws {
        let fixed: [(Error, Bool)] = [
            (UserStorageMigrationError.unknownStoreVersion, true),
            (UserStorageMigrationError.unavailableModel("v"), true),
            (UserStorageMigrationError.incompleteMigrationPath("a", "b"), true),
            (UserStorageMigrationError.interruptedMigration, false),
            (UserStorageMigrationError.missingWalletStore, true),
            (UserStorageMigrationError.missingWalletSecret("x"), true),
            (UserStorageMigrationError.emptyWalletSecret("x"), true),
            (UserStorageMigrationError.insufficientStorage, true),
            (UserStorageMigrationError.backupVerificationFailed("x"), true),
            (UserStorageMigrationError.accountInventoryMismatch, true),
            (UserStorageMigrationError.selectedAccountMismatch, true),
            (NSError(domain: NSPOSIXErrorDomain, code: Int(EIO)), true),
            (KeystoreSystemError(status: errSecInteractionNotAllowed), true),
        ]
        for (error, retryable) in fixed {
            let reason = UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
            let current = InMemorySettingsManager()
            current.setWalletMigrationRecovery(reason: reason)
            let marker = WalletMigrationRecoveryMarker.capture(current)
            XCTAssertEqual(marker.isRetryableStartupFailure, retryable, reason)
            XCTAssertEqual(marker.isStartupVerificationFailure, retryable, reason)
            XCTAssertEqual(marker.startupFailureCode, UserStorageMigrationError.privacySafeOutcomeCode(for: error))
            // A marker written by an older build without generations.
            let legacy = InMemorySettingsManager()
            legacy.set(value: true, for: SettingsKey.walletMigrationRecoveryRequired.rawValue)
            legacy.set(value: reason, for: SettingsKey.walletMigrationRecoveryReason.rawValue)
            XCTAssertEqual(WalletMigrationRecoveryMarker.capture(legacy).isRetryableStartupFailure, retryable, reason)
        }
        for reason in WalletMigrationRecoveryMarker.retryableJournalReadReasons {
            let settings = InMemorySettingsManager()
            settings.setWalletMigrationRecovery(reason: reason)
            XCTAssertTrue(WalletMigrationRecoveryMarker.capture(settings).isRetryableStartupFailure)
        }
        for reason in [WalletMigrationRecoveryMarker.accountCommitInterruptionReason,
                       "An unfinished or unverifiable wallet database migration blocks signing and wallet changes.",
                       "Wallet storage could not be verified safely (Unexpected). Existing wallet data and recovery copies were preserved.",
                       "Some other integrity check"] {
            let settings = InMemorySettingsManager()
            settings.setWalletMigrationRecovery(reason: reason)
            XCTAssertFalse(WalletMigrationRecoveryMarker.capture(settings).isRetryableStartupFailure, reason)
        }
        let invalid = InMemorySettingsManager()
        invalid.set(value: "not-json", for: SettingsKey.walletMigrationRecoveryRecord.rawValue)
        XCTAssertFalse(WalletMigrationRecoveryMarker.capture(invalid).isRetryableStartupFailure)
        XCTAssertFalse(WalletMigrationRecoveryMarker.capture(InMemorySettingsManager()).isRetryableStartupFailure)
    }

    func testTransientStartupFailureIsRetriedAutomaticallyUpToThreeRuns() throws {
        let settings = InMemorySettingsManager()
        var runs = 0
        let outcome = WalletStorageStartup.run(settings: settings, accountCommitRecovery: {
            runs += 1
            let marker = WalletMigrationRecoveryMarker.capture(settings)
            if runs < 3 { throw KeystoreSystemError(status: errSecInteractionNotAllowed) }
            if marker.required { try marker.clearAfterVerifiedStartup(settings) }
        }, retryDelay: { _ in }, migration: {})
        XCTAssertEqual(runs, 3)
        XCTAssertEqual(outcome, .ready)
        XCTAssertFalse(settings.walletMigrationRecoveryRequired)

        // A failure that is not retryable is shown after one run.
        let blocked = InMemorySettingsManager()
        blocked.setWalletMigrationRecovery(reason: "Some other integrity check")
        var blockedRuns = 0
        XCTAssertEqual(WalletStorageStartup.run(settings: blocked, accountCommitRecovery: { blockedRuns += 1 },
            retryDelay: { _ in }, migration: {}), .recoveryRequired)
        XCTAssertEqual(blockedRuns, 1)

        // An interrupted database migration is retried the same way: its
        // resume is proof-gated.
        let interrupted = InMemorySettingsManager()
        interrupted.setWalletMigrationRecovery(reason: UserStorageMigrationError
            .privacySafeRecoveryDescription(for: UserStorageMigrationError.interruptedMigration))
        XCTAssertTrue(WalletMigrationRecoveryMarker.capture(interrupted).isDatabaseInterruption)
        var migrationRuns = 0
        XCTAssertEqual(WalletStorageStartup.run(settings: interrupted, accountCommitRecovery: {},
            retryDelay: { _ in }, migration: {
                migrationRuns += 1
                if migrationRuns < 3 { throw UserStorageMigrationError.interruptedMigration }
                try WalletMigrationRecoveryMarker.capture(interrupted).clearAfterVerifiedActivation(interrupted)
            }), .ready)
        XCTAssertEqual(migrationRuns, 3)

        // Three failing runs end on the recovery screen, never a loop.
        let failing = InMemorySettingsManager()
        var failingRuns = 0
        XCTAssertEqual(WalletStorageStartup.run(settings: failing, accountCommitRecovery: {
            failingRuns += 1
            throw KeystoreSystemError(status: errSecInteractionNotAllowed)
        }, retryDelay: { _ in }, migration: {}), .recoveryRequired)
        XCTAssertEqual(failingRuns, 3)
        XCTAssertTrue(WalletMigrationRecoveryMarker.capture(failing).isRetryableStartupFailure)
    }

    // MARK: (b) Google Drive backups without a key verifier (App Store 3.8.6 format)

    private func appStore386Backup(address: String, phrase: String?, seed: Data? = nil, password: String,
                                   keyVerifierFor verifierAddress: String? = nil) throws -> Data {
        let encryption = EncryptionService()
        func encrypted(_ value: String) throws -> String {
            try XCTUnwrap(encryption.createEncryptedData(with: password, message: value)).toHex()
        }
        // `BackupFileFactory.createFile` at shared-features `ada44b24` (used by
        // App Store 3.8.6) wrote no `keyVerifier`.
        var fields: [String: Any] = ["name": "Backed up wallet", "address": address, "cryptoType": "SR25519",
                                     "backupAccountType": [phrase != nil ? "passphrase" : "seed"]]
        if let phrase { fields["encryptedMnemonicPhrase"] = try encrypted(phrase) }
        fields["encryptedSubstrateDerivationPath"] = try encrypted("")
        if let seed { fields["encryptedSeed"] = ["substrateSeed": try encrypted(seed.toHex())] }
        if let verifierAddress { fields["keyVerifier"] = try encrypted(verifierAddress) }
        return try JSONSerialization.data(withJSONObject: fields)
    }

    func testDriveBackupWithoutKeyVerifierRestoresMissingKeysOnTheRecoveryScreen() throws {
        let password = "backup-password-386"
        let reference = AddOnlyRecordingKeychain()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: reference.base)
        for condition in ["restored", "wrongPassword", "otherWallet", "otherVerifier"] {
            let device = try Installation()
            try KeySafetyStore.write([account], to: device.storeURL)
            // New iPhone: the database came back from iCloud, the keys did not.
            device.settings.setWalletMigrationRecovery(reason: UserStorageMigrationError
                .privacySafeRecoveryDescription(for: UserStorageMigrationError.missingWalletSecret("x")))
            let backup: Data
            switch condition {
            case "otherWallet":
                backup = try appStore386Backup(address: account.address, phrase: try phrase(entropy: 9, bytes: 16),
                                               password: password)
            case "otherVerifier":
                backup = try appStore386Backup(address: account.address, phrase: phrase12, password: password,
                                               keyVerifierFor: "cnOtherAddress")
            default:
                backup = try appStore386Backup(address: account.address, phrase: phrase12, password: password)
            }
            let marker = WalletMigrationRecoveryMarker.capture(device.settings)
            let migrator = try device.migrator()
            let attempt = {
                try WalletCloudBackupRecoveryService.restore(data: backup,
                    password: condition == "wrongPassword" ? "not-the-password" : password,
                    account: account, migrator: migrator, baseURL: device.directory,
                    lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.isolatedGate()))
            }
            if condition == "restored" {
                try attempt()
                // The phrase, then the derived seed and secret (add-only), as
                // the released writer stored them.
                XCTAssertEqual(try device.keychain.bytes(), try reference.bytes())
                XCTAssertEqual(device.keychain.added, [KeystoreTag.entropyTagForAddress(account.address),
                    KeystoreTag.seedTagForAddress(account.address), KeystoreTag.secretKeyTagForAddress(account.address)])
                XCTAssertFalse(device.keychain.changedExistingItems)
                XCTAssertEqual(try device.startup(), .ready)
                XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
                XCTAssertNotNil(try LegacySoraSecretResolver.resolve(account: account, keystore: device.keychain))
            } else {
                XCTAssertThrowsError(try attempt(), condition) { error in
                    if condition == "wrongPassword" || condition == "otherVerifier" {
                        guard case WalletCloudBackupRecoveryError.incorrectPassword = error else {
                            return XCTFail("\(condition): \(error)")
                        }
                    }
                }
                XCTAssertEqual(try device.keychain.allKeyIdentifiers(), [], condition)
                XCTAssertEqual(WalletMigrationRecoveryMarker.capture(device.settings), marker, condition)
            }
        }
    }

    func testCloudStorageOpenBackupProvesPasswordWithoutKeyVerifier() throws {
        let password = "backup-password-386"
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: InMemoryKeychain())
        let legacy = try appStore386Backup(address: account.address, phrase: phrase12, password: password)
        let opened = try CloudStorageService.openBackup(legacy, password: password, expectedAddress: account.address)
        XCTAssertEqual(opened.passphrase, phrase12)
        XCTAssertEqual(opened.address, account.address)
        XCTAssertThrowsError(try CloudStorageService.openBackup(legacy, password: "wrong", expectedAddress: account.address)) {
            guard case CloudStorageServiceError.incorectPassword = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertThrowsError(try CloudStorageService.openBackup(legacy, password: password, expectedAddress: "other")) {
            guard case CloudStorageServiceError.notFound = $0 else { return XCTFail("\($0)") }
        }
        let verified = try appStore386Backup(address: account.address, phrase: phrase12, password: password,
                                             keyVerifierFor: account.address)
        XCTAssertEqual(try CloudStorageService.openBackup(verified, password: password).passphrase, phrase12)
        let foreignVerifier = try appStore386Backup(address: account.address, phrase: phrase12, password: password,
                                                    keyVerifierFor: "another-address")
        XCTAssertThrowsError(try CloudStorageService.openBackup(foreignVerifier, password: password)) {
            guard case CloudStorageServiceError.incorectPassword = $0 else { return XCTFail("\($0)") }
        }
        let empty = try JSONSerialization.data(withJSONObject: ["name": "x", "address": account.address])
        XCTAssertThrowsError(try CloudStorageService.openBackup(empty, password: password)) {
            guard case CloudStorageServiceError.incorectJson = $0 else { return XCTFail("\($0)") }
        }
        let seedOnly = try appStore386Backup(address: account.address, phrase: nil,
                                             seed: Data(repeating: 4, count: 32), password: password)
        XCTAssertEqual(try CloudStorageService.openBackup(seedOnly, password: password).encryptedSeed?.substrateSeed,
                       Data(repeating: 4, count: 32).toHex())
    }

    func testOnboardingDriveRestoreRefusesKeysForAnotherAddressBeforeWriting() throws {
        let keychain = AddOnlyRecordingKeychain()
        let factory = AccountOperationFactory(keystore: keychain, recoveryGate: WalletRecoveryCapabilityGate(
            settings: InMemorySettingsManager(), unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }))
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: phrase12)
        let request = AccountCreationRequest(username: "Backup", type: .sora, derivationPath: "", cryptoType: .sr25519)
        let expected = try HistoricalWriter.phraseImport(phrase12, keystore: InMemoryKeychain())
        let mismatch = BaseAccountImportInteractor.requireAddress("cnSomeOtherAddress",
            of: factory.prepareAccountOperation(request: request, mnemonic: mnemonic))
        mismatch.start()
        XCTAssertThrowsError(try mismatch.extractResultData(throwing: BaseOperationError.parentOperationCancelled)) {
            guard case AccountCreateError.backupIdentityMismatch = $0 else { return XCTFail("\($0)") }
        }
        let match = BaseAccountImportInteractor.requireAddress(expected.address,
            of: factory.prepareAccountOperation(request: request, mnemonic: mnemonic))
        match.start()
        XCTAssertEqual(try match.extractResultData(throwing: BaseOperationError.parentOperationCancelled).account.address, expected.address)
        XCTAssertEqual(try keychain.allKeyIdentifiers(), [])
        XCTAssertEqual(keychain.added, [])
    }

    // MARK: (c) Reinstall: Keychain items only

    func testReinstallWithAppStore386KeychainReachesWelcomeBackAndImportAdoptsItems() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)
        let retained = try device.keychain.bytes()

        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertFalse(FileManager.default.fileExists(atPath: device.storeURL.path))
        XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
        XCTAssertEqual(try device.keychain.bytes(), retained)
        XCTAssertEqual(WalletRecoveryStateProbe.welcomeBack(keystore: device.keychain, settings: device.settings),
                       .welcomeBack(adoptableWallets: 1, walletsWithPhrase: 1, retainedPinUsable: true))

        let selection = try device.selectedWalletSettings()
        let imported = try device.importPhrase(phrase12, into: selection)
        XCTAssertEqual(imported.address, account.address)
        XCTAssertEqual(device.keychain.added, [])
        XCTAssertFalse(device.keychain.changedExistingItems)
        XCTAssertEqual(try device.keychain.bytes(), retained)
        let snapshot = try XCTUnwrap(device.networkStore().load())
        XCTAssertEqual(snapshot.wallets.map(\.secretSource), [.mnemonicEntropy])
        XCTAssertEqual(snapshot.selectedWalletId, account.address)
    }

    func testImportRefusesConflictingRetainedItemsWithoutWritingAnything() throws {
        for conflict in ["seed", "entropy", "secret", "derivation"] {
            let device = try Installation()
            let account = try HistoricalWriter.phraseImport(phrase12, keystore: InMemoryKeychain())
            switch conflict {
            case "seed": try device.keychain.base.addKey(Data(repeating: 1, count: 32),
                                                         with: KeystoreTag.seedTagForAddress(account.address))
            case "entropy": try device.keychain.base.addKey(Data(repeating: 1, count: 16),
                                                            with: KeystoreTag.entropyTagForAddress(account.address))
            case "secret": try device.keychain.base.addKey(Data(repeating: 1, count: 64),
                                                           with: KeystoreTag.secretKeyTagForAddress(account.address))
            default: try device.keychain.base.addKey(Data("//other".utf8),
                                                     with: KeystoreTag.deriviationTagForAddress(account.address))
            }
            let retained = try device.keychain.bytes()
            let selection = try device.selectedWalletSettings()
            XCTAssertThrowsError(try device.importPhrase(phrase12, into: selection), conflict) {
                guard case AccountCreateError.retainedKeyConflict = $0 else { return XCTFail("\(conflict): \($0)") }
            }
            XCTAssertEqual(device.keychain.added, [], conflict)
            XCTAssertFalse(device.keychain.changedExistingItems, conflict)
            XCTAssertEqual(try device.keychain.bytes(), retained, conflict)
            // The refused import closed its journal: no recovery marker, and
            // the next import (another phrase) works in the same session.
            XCTAssertFalse(device.settings.walletMigrationRecoveryRequired, conflict)
            XCTAssertEqual(try WalletAccountCommitJournalStore(baseURL: device.directory,
                recoveryGate: device.isolatedGate()).journalsForLegacyRecovery().map(\.stage), [.abandoned], conflict)
            let other = try device.importPhrase(try phrase(entropy: 0x31, bytes: 16), into: selection)
            XCTAssertNotEqual(other.address, account.address, conflict)
            XCTAssertFalse(device.settings.walletMigrationRecoveryRequired, conflict)
        }
    }

    func testLatchedReinstallMarkerIsClearedByStartupVerification() throws {
        for code in [UserStorageMigrationError.missingWalletStore, .selectedAccountMismatch] as [Error] +
                    [WalletIntegrityError.selectedAccountMissing] {
            for withEmptyStore in [false, true] {
                let device = try Installation()
                try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
                try device.keychain.base.addKey(Data("1234".utf8), with: KeystoreTag.pincode.rawValue)
                if withEmptyStore { try KeySafetyStore.write([], to: device.storeURL) }
                let retained = try device.keychain.bytes()
                // What 3.9.0 candidate builds latched after a reinstall.
                device.settings.setWalletMigrationRecovery(
                    reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: code))
                XCTAssertEqual(try device.startup(), .ready, "\(code)")
                XCTAssertFalse(device.settings.walletMigrationRecoveryRequired, "\(code)")
                XCTAssertEqual(try device.keychain.bytes(), retained)
                XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
            }
        }
    }

    func testRemovedAccountLeftoversAreIgnoredAndReimportAddsOnlyTheMissingPhrase() throws {
        let device = try Installation()
        let kept = try HistoricalWriter.phraseImport(phrase(entropy: 3, bytes: 16), username: "Kept", order: 0,
                                                     isSelected: true, keystore: device.keychain.base)
        let removed = try HistoricalWriter.phraseImport(phrase12, username: "Removed", order: 1, isSelected: false,
                                                        keystore: device.keychain.base)
        try HistoricalWriter.appStore386RemoveAccount(removed.address, keystore: device.keychain.base)
        try KeySafetyStore.write([kept], to: device.storeURL)
        let leftovers = try device.keychain.bytes()
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try device.networkStore().load()?.wallets.map(\.id), [kept.address])
        XCTAssertEqual(try device.keychain.bytes(), leftovers)

        let selection = try device.selectedWalletSettings(accounts: [kept])
        let reimported = try device.importPhrase(phrase12, into: selection)
        XCTAssertEqual(reimported.address, removed.address)
        XCTAssertEqual(device.keychain.added, [KeystoreTag.entropyTagForAddress(removed.address)])
        XCTAssertFalse(device.keychain.changedExistingItems)
        for (tag, bytes) in leftovers { XCTAssertEqual(try device.keychain.fetchKey(for: tag), bytes) }
    }

    func testRetainedKeychainDiscoveryAdoptsOnlyProvenWalletsAfterThePin() throws {
        let device = try Installation()
        let phraseWallet = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        let seedWallet = try HistoricalWriter.seedImport(Data(repeating: 21, count: 32), cryptoType: .ed25519,
                                                         keystore: device.keychain.base)
        let jsonSource = try SR25519KeypairFactory().createKeypairFromSeed(Data(repeating: 22, count: 32), chaincodeList: [])
        let jsonWallet = try HistoricalWriter.jsonImport(secret: jsonSource.privateKey().rawData(),
            publicKey: jsonSource.publicKey().rawData(), cryptoType: .sr25519, keystore: device.keychain.base)
        // A tag whose entropy derives another address: never adopted.
        let other = try HistoricalWriter.phraseImport(phrase(entropy: 7, bytes: 16), keystore: InMemoryKeychain())
        try device.keychain.base.addKey(Data(repeating: 9, count: 16), with: KeystoreTag.entropyTagForAddress(other.address))
        // A lone derivation tag is not a wallet.
        try device.keychain.base.addKey(Data("//1".utf8), with: "cnLoneDerivation-deriv")
        try device.keychain.base.addKey(Data("246810".utf8), with: KeystoreTag.pincode.rawValue)
        let retained = try device.keychain.bytes()

        let inventory = try RetainedKeychainWalletDiscovery.inventory(keystore: device.keychain,
                                                                      recoveryGate: device.isolatedGate())
        XCTAssertEqual(Set(inventory.adoptable.map(\.address)),
                       [phraseWallet.address, seedWallet.address, jsonWallet.address])
        XCTAssertEqual(inventory.unprovableAddressCount, 1)
        XCTAssertEqual(inventory.adoptable.first { $0.address == seedWallet.address }?.cryptoType, .ed25519)
        XCTAssertEqual(inventory.adoptable.first { $0.address == phraseWallet.address }?.hasPhrase, true)

        // The PIN gate counts failures; a wrong PIN changes nothing.
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("246810".utf8))
        do {
            try WalletRetainedPinGate.verify("000000", keystore: device.keychain, settings: device.settings)
            XCTFail("A wrong PIN was accepted")
        } catch {
            XCTAssertEqual(error as? WalletRetainedPinGate.Failure, .incorrectPin(attemptsBeforeWait: 2))
        }
        XCTAssertEqual(device.settings.integer(for: WalletRetainedPinGate.failureCountKey), 1)
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("246810".utf8))
        XCTAssertNoThrow(try WalletRetainedPinGate.verify("246810", keystore: device.keychain, settings: device.settings))
        XCTAssertNil(device.settings.integer(for: WalletRetainedPinGate.failureCountKey))

        let result = RetainedKeychainWalletDiscovery.restore(inventory.adoptable, keystore: device.keychain,
            selectedWalletSettings: try device.selectedWalletSettings(),
            lifecycleCoordinator: device.coordinator,
            recoveryGate: device.isolatedGate())
        XCTAssertTrue(result.failedAddresses.isEmpty)
        let restored = result.restored
        XCTAssertEqual(Set(restored.map(\.address)), Set(inventory.adoptable.map(\.address)))
        XCTAssertEqual(device.keychain.added, [])
        XCTAssertFalse(device.keychain.changedExistingItems)
        XCTAssertEqual(try device.keychain.bytes(), retained)
        let snapshot = try XCTUnwrap(device.networkStore().load())
        XCTAssertEqual(Set(snapshot.wallets.map(\.id)), Set(restored.map(\.address)))
        XCTAssertEqual(snapshot.selectedWalletId, inventory.adoptable.first?.address)
        XCTAssertFalse(snapshot.wallets.contains { $0.secretSource == .signingUnavailable })

        // Repeated wrong PINs lead to a wait (1, 5, 15, then 30 minutes),
        // never a permanent lock; the action stays offered.
        let start = Date()
        for attempt in 1...3 {
            XCTAssertThrowsError(try WalletRetainedPinGate.verify("111111", keystore: device.keychain,
                settings: device.settings, now: start)) {
                if attempt < 3 {
                    XCTAssertEqual($0 as? WalletRetainedPinGate.Failure, .incorrectPin(attemptsBeforeWait: 3 - attempt))
                } else {
                    guard case .locked? = $0 as? WalletRetainedPinGate.Failure else { return XCTFail("\($0)") }
                }
            }
        }
        XCTAssertThrowsError(try WalletRetainedPinGate.verify("246810", keystore: device.keychain,
            settings: device.settings, now: start.addingTimeInterval(30))) {
            guard case .locked? = $0 as? WalletRetainedPinGate.Failure else { return XCTFail("\($0)") }
        }
        XCTAssertTrue(WalletRecoveryStateProbe.welcomeBack(keystore: device.keychain, settings: device.settings)
            .options.canRestoreExistingKeys)
        XCTAssertNoThrow(try WalletRetainedPinGate.verify("246810", keystore: device.keychain,
            settings: device.settings, now: start.addingTimeInterval(61)))
        XCTAssertNil(WalletRetainedPinGate.lockedUntil(settings: device.settings, now: start))
        for failures in 4...8 {
            device.settings.set(value: failures - 1, for: WalletRetainedPinGate.failureCountKey)
            XCTAssertThrowsError(try WalletRetainedPinGate.verify("111111", keystore: device.keychain,
                settings: device.settings, now: start))
            let until = try XCTUnwrap(WalletRetainedPinGate.lockedUntil(settings: device.settings, now: start))
            XCTAssertEqual(until.timeIntervalSince(start), WalletRetainedPinGate.cooldown(afterFailures: failures),
                           accuracy: 1)
            XCTAssertLessThanOrEqual(WalletRetainedPinGate.cooldown(afterFailures: failures), 30 * 60)
            device.settings.removeValue(for: WalletRetainedPinGate.lockedUntilKey)
        }
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("246810".utf8))
    }

    func testShowRecoveryPhraseAfterThePinOnlyForProvenPhrases() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        let seedAccount = try HistoricalWriter.seedImport(Data(repeating: 31, count: 32), cryptoType: .sr25519,
                                                          keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("135790".utf8), with: KeystoreTag.pincode.rawValue)
        XCTAssertEqual(WalletRecoveryPhraseReveal.availableAddresses(accounts: [account, seedAccount],
            keystore: device.keychain, recoveryGate: device.isolatedGate()), [account.address])
        XCTAssertThrowsError(try WalletRecoveryPhraseReveal.reveal(pin: "000000", accounts: [account],
            keystore: device.keychain, settings: device.settings, recoveryGate: device.isolatedGate()))
        let entries = try WalletRecoveryPhraseReveal.reveal(pin: "135790", accounts: [account, seedAccount],
            keystore: device.keychain, settings: device.settings, recoveryGate: device.isolatedGate())
        XCTAssertEqual(entries.map(\.address), [account.address])
        XCTAssertEqual(entries.first?.words.joined(separator: " "), phrase12)
        XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
    }

    func testSetUpDeviceAgainMovesWalletFilesAsideAndNeverTouchesTheKeychain() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("1234".utf8), with: KeystoreTag.pincode.rawValue)
        try KeySafetyStore.write([account], to: device.storeURL)
        device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        XCTAssertEqual(try device.startup(), .ready)
        let storeBytes = try Data(contentsOf: device.storeURL)
        device.settings.set(value: true, for: "wallet.watchOnly.cnSomething")
        device.settings.setWalletMigrationRecovery(reason: "Some other integrity check")
        let marker = WalletMigrationRecoveryMarker.capture(device.settings)
        let keys = try device.keychain.bytes()
        let options = WalletRecoveryState.recovery(retryable: false, accountsMissingKeys: 0,
                                                   accountsWithPhrase: 0, retainedPinUsable: true).options
        XCTAssertTrue(options.canSetUpDeviceAgain)
        XCTAssertTrue(options.hasForwardActionBesidesRetry)

        let paths = WalletLocalStateSetAside.Paths(storeURL: device.storeURL,
            applicationSupportURL: device.directory,
            setAsideRootURL: device.directory.appendingPathComponent("WalletSetAside"))
        XCTAssertThrowsError(try WalletLocalStateSetAside.setAside(settings: device.settings,
            expectedMarker: WalletMigrationRecoveryMarker(required: false, reason: nil, generation: nil, reasonGeneration: nil),
            paths: paths, lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.isolatedGate())))
        let folder = try WalletLocalStateSetAside.setAside(settings: device.settings, expectedMarker: marker,
            paths: paths, lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.isolatedGate()))
        XCTAssertFalse(FileManager.default.fileExists(atPath: device.storeURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            device.directory.appendingPathComponent("WalletMigrationSafety").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            device.directory.appendingPathComponent("SORA/WalletNetworks").path))
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("CoreData/UserDataModel.sqlite")), storeBytes)
        XCTAssertTrue(FileManager.default.fileExists(atPath:
            folder.appendingPathComponent("CoreData/WalletMigrationSafety").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("WalletNetworks").path))
        let preserved = try XCTUnwrap(PropertyListSerialization.propertyList(from:
            Data(contentsOf: folder.appendingPathComponent("wallet-settings.plist")), format: nil) as? [String: Any])
        XCTAssertNotNil(preserved[SettingsKey.selectedAccount.rawValue])
        XCTAssertEqual(preserved["wallet.watchOnly.cnSomething"] as? Bool, true)
        XCTAssertFalse(device.settings.hasRetainedWalletSettings())
        XCTAssertFalse(device.settings.hasRetainedWatchOnlyWallet())
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        // Keychain untouched; the next launch is a welcome back.
        XCTAssertEqual(try device.keychain.bytes(), keys)
        XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
        XCTAssertEqual(try device.migrator().retainedWalletEvidenceKind(), .keychainOnly)
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
    }

    func testEveryRecoveryStateOffersAForwardAction() {
        for retryable in [false, true] {
            for missing in [0, 2] {
                for phrases in [0, 1] {
                    for pin in [false, true] {
                        let options = WalletRecoveryState.recovery(retryable: retryable, accountsMissingKeys: missing,
                            accountsWithPhrase: phrases, retainedPinUsable: pin).options
                        XCTAssertTrue(options.hasForwardActionBesidesRetry)
                        XCTAssertEqual(options.canRetry, retryable)
                        XCTAssertEqual(options.canRestoreExistingKeys, missing > 0)
                        XCTAssertEqual(options.canShowPhraseAfterPin, pin && phrases > 0)
                        XCTAssertTrue(options.canExport && options.canSetUpDeviceAgain)
                    }
                }
            }
        }
        for adoptable in [0, 3] {
            for pin in [false, true] {
                let options = WalletRecoveryState.welcomeBack(adoptableWallets: adoptable, walletsWithPhrase: adoptable,
                                                              retainedPinUsable: pin).options
                XCTAssertTrue(options.hasForwardActionBesidesRetry)
                XCTAssertFalse(options.canRetry)
                XCTAssertTrue(options.canRestoreFromPhrase && options.canRestoreFromDrive && options.canSetUpDeviceAgain)
                XCTAssertEqual(options.canRestoreExistingKeys, pin && adoptable > 0)
            }
        }
    }

    // MARK: (d, g) New iPhone and per-account read-only

    func testNewIPhoneFromICloudBackupOpensReadOnlyAndRestoresEachAccount() throws {
        let original = try Installation()
        let first = try HistoricalWriter.phraseImport(phrase12, username: "First", order: 0, isSelected: true,
                                                      keystore: original.keychain.base)
        let fifteen = try phrase(entropy: 15, bytes: 20)
        let second = try HistoricalWriter.phraseImport(fifteen, username: "Second", order: 1, isSelected: false,
                                                       keystore: original.keychain.base)
        try KeySafetyStore.write([first, second], to: original.storeURL)
        XCTAssertEqual(try original.startup(), .ready)
        let originalSnapshot = try XCTUnwrap(original.networkStore().load())

        for marker in [nil, UserStorageMigrationError.missingWalletSecret("x")] as [Error?] {
            // iCloud restore: files and settings come back, ThisDeviceOnly keys do not.
            let restored = try Installation()
            try FileManager.default.removeItem(at: restored.directory)
            try FileManager.default.copyItem(at: original.directory, to: restored.directory)
            if let marker {
                restored.settings.setWalletMigrationRecovery(
                    reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: marker))
            }
            XCTAssertEqual(try restored.startup(), .ready)
            XCTAssertFalse(restored.settings.walletMigrationRecoveryRequired)
            let snapshot = try XCTUnwrap(restored.networkStore().load())
            // The recorded sources and Nexus children are kept; nothing can sign.
            XCTAssertEqual(snapshot.wallets, originalSnapshot.wallets)
            XCTAssertEqual(snapshot.accounts, originalSnapshot.accounts)
            XCTAssertNil(try LegacySoraSecretResolver.resolve(account: first, keystore: restored.keychain))
            XCTAssertEqual(try restored.rootDecision(selected: first), [.pincodeSetup])

            let gate = restored.isolatedGate()
            let migrator = try restored.migrator(gate: gate)
            try migrator.restoreKeysForReadOnlyAccount(address: first.address, mnemonic: phrase12, derivationPath: "",
                networkStore: restored.networkStore(),
                lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate))
            XCTAssertEqual(restored.keychain.added, [KeystoreTag.entropyTagForAddress(first.address),
                KeystoreTag.seedTagForAddress(first.address), KeystoreTag.secretKeyTagForAddress(first.address)])
            XCTAssertNotNil(try LegacySoraSecretResolver.resolve(account: first, keystore: restored.keychain))
            XCTAssertNil(try LegacySoraSecretResolver.resolve(account: second, keystore: restored.keychain))
            XCTAssertThrowsError(try migrator.restoreKeysForReadOnlyAccount(address: second.address,
                mnemonic: phrase12, derivationPath: "", networkStore: restored.networkStore(),
                lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate)))
            try migrator.restoreKeysForReadOnlyAccount(address: second.address, mnemonic: fifteen, derivationPath: "",
                networkStore: restored.networkStore(),
                lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate))
            XCTAssertEqual(try restored.startup(), .ready)
            XCTAssertEqual(try restored.networkStore().load()?.wallets, originalSnapshot.wallets)
            XCTAssertFalse(restored.keychain.changedExistingItems)
        }
    }

    func testOneKeylessAccountIsReadOnlyAndOthersStayUsable() throws {
        let device = try Installation()
        let usable = try HistoricalWriter.phraseImport(phrase12, username: "Usable", order: 0, isSelected: true,
                                                       keystore: device.keychain.base)
        let keyless = try HistoricalWriter.phraseImport(phrase(entropy: 4, bytes: 16), username: "Keyless", order: 1,
                                                        isSelected: false, keystore: InMemoryKeychain())
        try KeySafetyStore.write([usable, keyless], to: device.storeURL)
        XCTAssertEqual(try device.startup(), .ready)
        var snapshot = try XCTUnwrap(device.networkStore().load())
        XCTAssertEqual(snapshot.wallets.first { $0.id == usable.address }?.secretSource, .mnemonicEntropy)
        XCTAssertEqual(snapshot.wallets.first { $0.id == keyless.address }?.secretSource, .signingUnavailable)
        XCTAssertEqual(snapshot.accounts.filter { $0.walletId == keyless.address }.map(\.networkId), [.sora2])
        XCTAssertEqual(Set(snapshot.accounts.filter { $0.walletId == usable.address }.map(\.networkId)),
                       NexusNetworkConfiguration.admittedWalletNetworkIds)
        XCTAssertNotNil(try LegacySoraSecretResolver.resolve(account: usable, keystore: device.keychain))

        // Restoring the keyless account upgrades its placeholder and adds its
        // Nexus children; the other wallet is unchanged.
        let gate = device.isolatedGate()
        try device.migrator(gate: gate).restoreKeysForReadOnlyAccount(address: keyless.address,
            mnemonic: phrase(entropy: 4, bytes: 16), derivationPath: "", networkStore: device.networkStore(),
            lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate))
        snapshot = try XCTUnwrap(device.networkStore().load())
        XCTAssertEqual(snapshot.wallets.first { $0.id == keyless.address }?.secretSource, .mnemonicEntropy)
        XCTAssertEqual(Set(snapshot.accounts.filter { $0.walletId == keyless.address }.map(\.networkId)),
                       NexusNetworkConfiguration.admittedWalletNetworkIds)
        XCTAssertEqual(device.keychain.added, [KeystoreTag.entropyTagForAddress(keyless.address),
            KeystoreTag.seedTagForAddress(keyless.address), KeystoreTag.secretKeyTagForAddress(keyless.address)])
    }

    func testSigningReportsKeysNotOnThisDeviceWithAMessage() {
        let message = SigningWrapperError.keysNotOnThisDevice.localizedDescription
        XCTAssertTrue(message.contains("iPhone") || message.contains("iPhone"))
        XCTAssertFalse(message.lowercased().contains("reinstall"))
        XCTAssertFalse(message.lowercased().contains("delete"))
    }

    // MARK: (e) Soft junctions

    func testSoftJunctionSr25519StoredSecretWithAnotherNonceUpgradesAndSigns() throws {
        let path = "//hard/soft"
        let junction = try SubstrateJunctionFactory().parse(path: path)
        let seed = try SeedFactory().deriveSeed(from: phrase12, password: junction.password ?? "").seed.miniSeed
        let derived = try SR25519KeypairFactory().createKeypairFromSeed(seed, chaincodeList: junction.chaincodes)
        let again = try SR25519KeypairFactory().createKeypairFromSeed(seed, chaincodeList: junction.chaincodes)
        XCTAssertEqual(derived.privateKey().rawData().prefix(32), again.privateKey().rawData().prefix(32))
        XCTAssertEqual(derived.publicKey().rawData(), again.publicKey().rawData())

        // What App Store 3.8.6 stored: same scalar, its own nonce.
        var stored = derived.privateKey().rawData()
        stored.replaceSubrange(32..<64, with: Data((0..<32).map { UInt8(255 - $0) }))
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, path: path, keystore: device.keychain.base)
        try device.keychain.base.updateKey(stored, with: KeystoreTag.secretKeyTagForAddress(account.address))
        try LegacySoraIdentityValidator.validate(address: account.address, publicKey: account.publicKeyData,
            cryptoType: .sr25519, networkType: account.networkType, derivationPath: path,
            entropy: try device.keychain.fetchKey(for: KeystoreTag.entropyTagForAddress(account.address)),
            rawSeed: try device.keychain.fetchKey(for: KeystoreTag.seedTagForAddress(account.address)),
            secret: stored, recoveryGate: device.isolatedGate())

        var wrongScalar = stored
        wrongScalar[3] ^= 0x10
        XCTAssertThrowsError(try LegacySoraIdentityValidator.validate(address: account.address,
            publicKey: account.publicKeyData, cryptoType: .sr25519, networkType: account.networkType,
            derivationPath: path, entropy: nil, rawSeed: seed, secret: wrongScalar, recoveryGate: device.isolatedGate()))

        try KeySafetyStore.write([account], to: device.storeURL)
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try device.networkStore().load()?.wallets.first?.secretSource, .mnemonicEntropy)
        let secret = try XCTUnwrap(LegacySoraSecretResolver.resolve(account: account, keystore: device.keychain))
        XCTAssertEqual(secret, stored)
        XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain))

        // Importing the soft-path phrase again adopts the stored secret.
        let reimport = try Installation()
        try reimport.keychain.base.addKey(stored, with: KeystoreTag.secretKeyTagForAddress(account.address))
        let imported = try reimport.importPhrase(phrase12, path: path, into: reimport.selectedWalletSettings())
        XCTAssertEqual(imported.address, account.address)
        XCTAssertEqual(try reimport.keychain.fetchKey(for: KeystoreTag.secretKeyTagForAddress(account.address)), stored)
        XCTAssertEqual(Set(reimport.keychain.added), [KeystoreTag.entropyTagForAddress(account.address),
            KeystoreTag.deriviationTagForAddress(account.address), KeystoreTag.seedTagForAddress(account.address)])
        XCTAssertFalse(reimport.keychain.changedExistingItems)
    }

    // MARK: (f) Unverified failed attempt

    func testFailedAttemptWithoutVerifiedBackupIsSetAsideAndRetried() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try KeySafetyStore.write([account], to: device.storeURL)
        let keys = try device.keychain.bytes()
        var failures = 0
        let failing = try device.migrator(afterCopy: { _ in
            failures += 1
            throw UserStorageMigrationError.backupVerificationFailed("synthetic")
        })
        XCTAssertEqual(WalletStorageStartup.run(settings: device.settings) {
            try failing.migrateAtStartup(lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.gate()),
                                         hasUnresolvedAccountCommit: { false })
        }, .recoveryRequired)
        XCTAssertEqual(failures, 1)
        let marker = WalletMigrationRecoveryMarker.capture(device.settings)
        XCTAssertEqual(marker.startupFailureCode, "backup_verification_failed")
        XCTAssertTrue(marker.isRetryableStartupFailure)
        let safety = device.directory.appendingPathComponent("WalletMigrationSafety")
        let failedAttempt = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: safety,
            includingPropertiesForKeys: nil).first)
        let failedJournal = try Data(contentsOf: failedAttempt.appendingPathComponent("journal.json"))

        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        let superseded = device.directory.appendingPathComponent("WalletMigrationSuperseded")
            .appendingPathComponent(failedAttempt.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: superseded.appendingPathComponent("journal.json")), failedJournal)
        let attempts = try FileManager.default.contentsOfDirectory(at: safety, includingPropertiesForKeys: nil)
        XCTAssertEqual(attempts.count, 1)
        XCTAssertNotEqual(attempts.first?.lastPathComponent, failedAttempt.lastPathComponent)
        XCTAssertFalse(WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: device.storeURL))
        XCTAssertEqual(try device.keychain.bytes(), keys)
    }

    // MARK: (h) Stale 2.x selection

    func testTwoXInstallationsUpgradeWithAnySelectionState() throws {
        // 2.x (`e52beedd`): version-1 rows without `isSelected`; the selection
        // lived only in UserDefaults `selectedAccount` (never cleared by 3.x).
        for selection in ["valid", "removedAccount", "absent"] {
            let device = try Installation()
            let first = try HistoricalWriter.phraseImport(phrase12, username: "First", order: 4, isSelected: false,
                                                          keystore: device.keychain.base)
            let second = try HistoricalWriter.phraseImport(phrase(entropy: 6, bytes: 16), username: "Second", order: 2,
                                                           isSelected: false, keystore: device.keychain.base)
            let removed = try HistoricalWriter.phraseImport(phrase(entropy: 8, bytes: 16), keystore: InMemoryKeychain())
            try KeySafetyStore.write([first, second], to: device.storeURL, version: .version1)
            switch selection {
            case "valid": device.settings.set(value: first, for: SettingsKey.selectedAccount.rawValue)
            case "removedAccount": device.settings.set(value: removed, for: SettingsKey.selectedAccount.rawValue)
            default: break
            }
            let keys = try device.keychain.bytes()
            XCTAssertEqual(try device.startup(), .ready, selection)
            XCTAssertFalse(device.settings.walletMigrationRecoveryRequired, selection)
            // The valid 2.x choice is kept; otherwise the lowest order wins.
            let expected = selection == "valid" ? first.address : second.address
            let rows = try KeySafetyStore.rows(at: device.storeURL)
            XCTAssertEqual(rows.filter(\.isSelected).map(\.address), [expected], selection)
            XCTAssertEqual(try device.networkStore().load()?.selectedWalletId, expected, selection)
            XCTAssertEqual(try device.keychain.bytes(), keys, selection)
            XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems, selection)
        }
    }

    func testSeveralSelectedRowsResolveAndAreRepairedToExactlyOne() throws {
        let device = try Installation()
        let first = try HistoricalWriter.phraseImport(phrase12, username: "First", order: 4, isSelected: true,
                                                      keystore: device.keychain.base)
        let second = try HistoricalWriter.phraseImport(phrase(entropy: 6, bytes: 16), username: "Second", order: 2,
                                                       isSelected: true, keystore: device.keychain.base)
        try KeySafetyStore.write([first, second], to: device.storeURL)
        device.settings.set(value: first, for: SettingsKey.selectedAccount.rawValue)
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try device.networkStore().load()?.selectedWalletId, first.address)

        // The startup repair writes exactly one selected row, which is what
        // App Store 3.8.6 reads.
        let selection = try device.selectedWalletSettings(accounts: [first, second])
        XCTAssertTrue(SelectedWalletSettings.needsSelectionRepair(accounts: [first, second]))
        let done = DispatchSemaphore(value: 0)
        var saved: Result<AccountItem, Error>?
        selection.performSave(value: first) { result in
            saved = result
            done.signal()
        }
        done.wait()
        XCTAssertEqual(try saved?.get().address, first.address)
        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            selection.storageFacade.createRepository(mapper: AnyCoreDataMapper(AccountItemMapper()))
        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([fetch], waitUntilFinished: true)
        let stored = try fetch.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertEqual(stored.filter(\.isSelected).map(\.address), [first.address])
        XCTAssertFalse(SelectedWalletSettings.needsSelectionRepair(accounts: stored))
        XCTAssertEqual(selection.currentAccount?.isSelected, true)
    }

    func testWelcomeBackScreenShowsActionsFromFacts() {
        let controller = WalletWelcomeBackViewController(onContinueToOnboarding: {}, onWalletsRestored: {})
        controller.loadViewIfNeeded()
        func button(_ identifier: String) -> UIButton? {
            var stack: [UIView] = [controller.view]
            while let view = stack.popLast() {
                if let button = view as? UIButton, button.accessibilityIdentifier == identifier { return button }
                stack.append(contentsOf: view.subviews)
            }
            return nil
        }
        controller.apply(WalletRecoveryState.welcomeBack(adoptableWallets: 0, walletsWithPhrase: 0,
                                                         retainedPinUsable: true).options)
        XCTAssertEqual(button("wallet-welcome-back-restore-found")?.isHidden, true)
        XCTAssertEqual(button("wallet-welcome-back-phrase")?.isHidden, false)
        XCTAssertEqual(button("wallet-welcome-back-drive")?.isHidden, false)
        XCTAssertEqual(button("wallet-welcome-back-set-up-again")?.isHidden, false)
        controller.apply(WalletRecoveryState.welcomeBack(adoptableWallets: 2, walletsWithPhrase: 1,
                                                         retainedPinUsable: true).options)
        XCTAssertEqual(button("wallet-welcome-back-restore-found")?.isHidden, false)
        XCTAssertEqual(button("wallet-welcome-back-show-phrase")?.isHidden, false)
        XCTAssertEqual(button("wallet-welcome-back-restore-found")?.title(for: .normal),
                       WalletUX.text("Restore wallets found on this iPhone"))
    }

    // MARK: (i) Scoped copies for global-only accounts and downgrade safety

    private func versionOneUpgradedInstallation() throws -> (Installation, AccountItem, Data) {
        let device = try Installation()
        let phrase15 = try phrase(entropy: 0x11, bytes: 20)
        let entropy = try HistoricalWriter.version1(phrase: phrase15, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("1357".utf8), with: KeystoreTag.pincode.rawValue)
        device.settings.set(value: "Version 1 wallet", for: KeystoreTag.legacyUsername.rawValue)
        // The account row the explicit legacy upgrade commits (sr25519, no path).
        let seed = try SeedFactory().deriveSeed(from: phrase15, password: "").seed.miniSeed
        let pair = try SR25519KeypairFactory().createKeypairFromSeed(seed, chaincodeList: [])
        let account = AccountItem(address: try SS58AddressFactory().address(fromAccountId: pair.publicKey().rawData(),
            type: Chain.sora.addressType()), cryptoType: .sr25519, networkType: Chain.sora.addressType(),
            username: "Version 1 wallet", publicKeyData: pair.publicKey().rawData(),
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        try KeySafetyStore.write([account], to: device.storeURL)
        device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        return (device, account, entropy)
    }

    func testGlobalOnlyAccountGetsScopedCopiesAddOnlyAndSurvivesAppStore386() throws {
        let (device, account, entropy) = try versionOneUpgradedInstallation()
        let before = try device.keychain.bytes()

        // Without the copies, App Store 3.8.6 wipes settings and deletes the
        // only copy of the secret.
        let unprotected = AddOnlyRecordingKeychain()
        for (tag, bytes) in before { try unprotected.base.addKey(bytes, with: tag) }
        let outcome = try AppStore386Launch.run(storeURL: device.storeURL, keystore: unprotected.base,
                                                settings: InMemorySettingsManager())
        XCTAssertTrue(outcome.settingsWiped)
        XCTAssertFalse(try unprotected.base.checkKey(for: KeystoreTag.legacyEntropy.rawValue))
        XCTAssertFalse(try AppStore386Launch.canSign(account, keystore: unprotected.base))

        XCTAssertEqual(try device.startup(), .ready)
        let snapshot = try XCTUnwrap(device.networkStore().load())
        XCTAssertEqual(snapshot.wallets.first?.secretSource, .legacyMnemonicEntropy)
        XCTAssertEqual(Set(device.keychain.added), [KeystoreTag.entropyTagForAddress(account.address),
            KeystoreTag.seedTagForAddress(account.address), KeystoreTag.secretKeyTagForAddress(account.address)])
        XCTAssertEqual(device.keychain.added.first, KeystoreTag.entropyTagForAddress(account.address))
        XCTAssertFalse(device.keychain.changedExistingItems)
        for (tag, bytes) in before { XCTAssertEqual(try device.keychain.fetchKey(for: tag), bytes) }
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.entropyTagForAddress(account.address)), entropy)
        // Idempotent.
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(device.keychain.added.count, 3)

        // A later App Store 3.8.6 launch keeps everything it needs.
        let downgraded = try AppStore386Launch.run(storeURL: device.storeURL, keystore: device.keychain.base,
                                                   settings: device.settings)
        XCTAssertEqual(downgraded.selected?.address, account.address)
        XCTAssertFalse(downgraded.settingsWiped)
        XCTAssertFalse(try device.keychain.base.checkKey(for: KeystoreTag.legacyEntropy.rawValue))
        XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain.base))
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.entropyTagForAddress(account.address)), entropy)
        // Back on 3.9.0 the account still opens and signs from the scoped copies.
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertNotNil(try LegacySoraSecretResolver.resolve(account: account, keystore: device.keychain))
    }

    func testScopedBackfillStopsAtAConflictAndResumesAfterAnInterruption() throws {
        let (conflicted, account, entropy) = try versionOneUpgradedInstallation()
        XCTAssertEqual(try conflicted.startup(), .ready)
        // Simulate a run interrupted after the phrase copy, then a foreign
        // (non-matching) seed item.
        let snapshot = try XCTUnwrap(conflicted.networkStore().load())
        let interrupted = AddOnlyRecordingKeychain()
        for (tag, bytes) in try conflicted.keychain.bytes() where !tag.hasSuffix("-seed") && !tag.hasSuffix("-secretKey") {
            try interrupted.base.addKey(bytes, with: tag)
        }
        XCTAssertEqual(try interrupted.base.fetchKey(for: KeystoreTag.entropyTagForAddress(account.address)), entropy)
        var result = try LegacyGlobalEntropyScopedBackfill.run(accounts: [account], snapshot: snapshot,
            keystore: interrupted, recoveryGate: conflicted.isolatedGate())
        XCTAssertEqual(result.completed, [account.address])
        XCTAssertEqual(interrupted.added, [KeystoreTag.seedTagForAddress(account.address),
                                           KeystoreTag.secretKeyTagForAddress(account.address)])

        let foreign = AddOnlyRecordingKeychain()
        for (tag, bytes) in try interrupted.bytes() where !tag.hasSuffix("-seed") && !tag.hasSuffix("-secretKey") {
            try foreign.base.addKey(bytes, with: tag)
        }
        try foreign.base.addKey(Data(repeating: 7, count: 32), with: KeystoreTag.seedTagForAddress(account.address))
        let foreignBefore = try foreign.bytes()
        result = try LegacyGlobalEntropyScopedBackfill.run(accounts: [account], snapshot: snapshot,
            keystore: foreign, recoveryGate: conflicted.isolatedGate())
        XCTAssertEqual(result.conflicts, [account.address])
        XCTAssertEqual(foreign.added, [])
        XCTAssertEqual(try foreign.bytes(), foreignBefore)
    }

    func testDowngradeToAppStore386AfterUpgradeLosesNoKey() throws {
        let device = try Installation()
        let first = try HistoricalWriter.phraseImport(phrase12, path: "//1/2", username: "First", order: 0,
                                                      isSelected: true, keystore: device.keychain.base)
        let second = try HistoricalWriter.seedImport(Data(repeating: 41, count: 32), cryptoType: .ed25519,
                                                     username: "Second", order: 1, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("2468".utf8), with: KeystoreTag.pincode.rawValue)
        try KeySafetyStore.write([first, second.replacingSelection(false)], to: device.storeURL)
        let before = try device.keychain.bytes()
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
        // 3.8.6 opens the same store with its own model and finds its selection.
        let outcome = try AppStore386Launch.run(storeURL: device.storeURL, keystore: device.keychain.base,
                                                settings: device.settings)
        XCTAssertEqual(outcome.selected?.address, first.address)
        XCTAssertFalse(outcome.settingsWiped)
        for account in [first, second] { XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain.base)) }
        for (tag, bytes) in before { XCTAssertEqual(try device.keychain.base.fetchKey(for: tag), bytes) }
        // Upgrading again over what 3.8.6 left works.
        XCTAssertEqual(try device.startup(), .ready)
    }

    // MARK: (j) 15/18/21-word phrases

    func testFifteenEighteenTwentyOneWordPhrasesImportForSora2Only() throws {
        let interactor = AccountImportInteractor(accountOperationFactory: AccountOperationFactory(keystore: InMemoryKeychain()),
            accountRepository: AnyDataProviderRepository(UserDataStorageTestFacade().createRepository(
                mapper: AnyCoreDataMapper(AccountItemMapper())) as CoreDataRepository<AccountItem, CDAccountItem>),
            operationManager: OperationManager(), settings: try Installation().selectedWalletSettings(),
            keystoreImportService: KeystoreImportService(logger: Logger.shared), eventCenter: EventCenter.shared)
        XCTAssertEqual(interactor.allowedMnemonicWordCounts, [12, 15, 18, 21, 24])
        for (bytes, words) in [(20, 15), (24, 18), (28, 21)] {
            let device = try Installation()
            let words15 = try phrase(entropy: UInt8(bytes), bytes: bytes)
            XCTAssertEqual(words15.split(separator: " ").count, words)
            let account = try device.importPhrase(words15, into: device.selectedWalletSettings())
            let snapshot = try XCTUnwrap(device.networkStore().load())
            XCTAssertEqual(snapshot.wallets.first { $0.id == account.address }?.secretSource, .legacyMnemonicEntropy)
            XCTAssertEqual(snapshot.accounts.map(\.networkId), [.sora2])
            XCTAssertEqual(Set(device.keychain.added), [KeystoreTag.entropyTagForAddress(account.address),
                KeystoreTag.seedTagForAddress(account.address), KeystoreTag.secretKeyTagForAddress(account.address)])
        }
    }

    // MARK: (k) 3/6/9-word wallets imported by App Store 3.8.6

    func testThreeSixNineWordRetainedWalletsRemainUsableOnSora2() throws {
        for words in [3, 6, 9] {
            let short = try shortPhrase(words: words)
            let device = try Installation()
            let account = try HistoricalWriter.phraseImport(short, keystore: device.keychain.base)
            let entropy = try device.keychain.fetchKey(for: KeystoreTag.entropyTagForAddress(account.address))
            XCTAssertEqual(entropy.count, words * 4 / 3, "\(words)")
            XCTAssertFalse(WalletMnemonicWordPolicy.isDerivableEntropy(entropy))
            try KeySafetyStore.write([account], to: device.storeURL)
            XCTAssertEqual(try device.startup(), .ready, "\(words)")
            XCTAssertEqual(try device.networkStore().load()?.wallets.first?.secretSource, .rawSeed, "\(words)")
            XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain.base))
            // Without the stored secret the seed backs the signer; the short
            // entropy is never expanded.
            let seedOnly = InMemoryKeychain()
            try seedOnly.addKey(entropy, with: KeystoreTag.entropyTagForAddress(account.address))
            try seedOnly.addKey(try device.keychain.fetchKey(for: KeystoreTag.seedTagForAddress(account.address)),
                                with: KeystoreTag.seedTagForAddress(account.address))
            XCTAssertNotNil(try LegacySoraSecretResolver.resolve(account: account, keystore: seedOnly))
            XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
        }
    }

    // MARK: (l) Interrupted ordinary create or import

    func testInterruptedImportBeforeCoreDataIsSetAsideAndTheItemsAreAdopted() throws {
        for markerReason in [nil, WalletMigrationRecoveryMarker.accountCommitInterruptionReason,
                             UserStorageMigrationError.privacySafeRecoveryDescription(
                                for: WalletNetworkMigrationError.snapshotVerificationFailed)] {
            let device = try Installation()
            let account = try HistoricalWriter.phraseImport(phrase12, keystore: InMemoryKeychain())
            // The import was killed after its secrets were saved, before Core Data.
            let gate = device.isolatedGate()
            let journals = try WalletAccountCommitJournalStore(baseURL: device.directory, recoveryGate: gate)
            var journal = try journals.begin(walletId: account.address, existingWalletIds: [])
            try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
            journal = try journals.advance(journal, to: .secretsPersisted)
            if let markerReason { device.settings.setWalletMigrationRecovery(reason: markerReason) }
            let keys = try device.keychain.bytes()
            XCTAssertEqual(try device.startup(), .ready, markerReason ?? "none")
            XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
            XCTAssertEqual(try journals.journalsForLegacyRecovery().map(\.stage), [.abandoned])
            XCTAssertEqual(try device.keychain.bytes(), keys)
            XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
            XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
            // A second import of the same phrase adopts the items and completes.
            let imported = try device.importPhrase(phrase12, into: device.selectedWalletSettings())
            XCTAssertEqual(imported.address, account.address)
            XCTAssertEqual(device.keychain.added, [])
        }
    }

    func testInterruptedImportAfterCoreDataCommitRollsForward() throws {
        for stage in [WalletAccountCommitStage.secretsPersisted, .coreDataCommitted, .networkModelActivated] {
            let device = try Installation()
            let existing = try HistoricalWriter.phraseImport(phrase(entropy: 2, bytes: 16), username: "Existing",
                order: 0, isSelected: false, keystore: device.keychain.base)
            let gate = device.isolatedGate()
            let journals = try WalletAccountCommitJournalStore(baseURL: device.directory, recoveryGate: gate)
            var journal = try journals.begin(walletId: try HistoricalWriter.phraseImport(phrase12,
                keystore: InMemoryKeychain()).address, existingWalletIds: [existing.address])
            let account = try HistoricalWriter.phraseImport(phrase12, username: "New", order: 1, isSelected: true,
                                                            keystore: device.keychain.base)
            for next in [WalletAccountCommitStage.secretsPersisted, .coreDataCommitted, .networkModelActivated]
                where [.secretsPersisted, .coreDataCommitted, .networkModelActivated].firstIndex(of: next)!
                    <= [.secretsPersisted, .coreDataCommitted, .networkModelActivated].firstIndex(of: stage)! {
                journal = try journals.advance(journal, to: next)
            }
            // The Core Data save had completed (rows written by performInsertAndSelect).
            try KeySafetyStore.write([existing, account], to: device.storeURL)
            let keys = try device.keychain.bytes()
            XCTAssertEqual(try device.startup(), .ready, "\(stage)")
            XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
            XCTAssertEqual(try journals.journalsForLegacyRecovery().map(\.stage), [.activated])
            XCTAssertEqual(device.settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue)?.address,
                           account.address)
            let snapshot = try XCTUnwrap(device.networkStore().load())
            XCTAssertEqual(Set(snapshot.wallets.map(\.id)), [existing.address, account.address])
            XCTAssertEqual(snapshot.selectedWalletId, account.address)
            XCTAssertEqual(try device.keychain.bytes(), keys)
            XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
        }
    }

    // MARK: Review fixes

    /// An abandoned import journal is finished. It must not stop a database
    /// attempt killed on a later launch from being resumed (it used to send
    /// every startup into a branch that refused while the attempt existed).
    func testAbandonedJournalDoesNotBlockResumingAKilledDatabaseAttempt() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: InMemoryKeychain())
        // 1. An onboarding import killed after its journal began.
        let journals = try WalletAccountCommitJournalStore(baseURL: device.directory,
                                                           recoveryGate: device.isolatedGate())
        _ = try journals.begin(walletId: account.address, existingWalletIds: [])
        try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try journals.journalsForLegacyRecovery().map(\.stage), [.abandoned])
        // 2. The user imports again; the row reaches the store.
        let imported = try device.importPhrase(phrase12, into: device.selectedWalletSettings())
        XCTAssertEqual(imported.address, account.address)
        try KeySafetyStore.write([imported], to: device.storeURL)
        XCTAssertEqual(Set(try journals.journalsForLegacyRecovery().map(\.stage)), [.abandoned, .activated])
        // 3. The next launch's first safety backup is killed mid-copy.
        var killed: Installation?
        _ = try device.startup(checkpoint: { phase in
            guard phase == .backupCopied, killed == nil else { return }
            killed = try device.copy()
        })
        let restarted = try XCTUnwrap(killed)
        XCTAssertTrue(WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: restarted.storeURL))
        XCTAssertFalse(restarted.settings.walletMigrationRecoveryRequired)
        // 4. The following launches finish or replace that attempt.
        XCTAssertEqual(try restarted.startup(), .ready)
        XCTAssertFalse(restarted.settings.walletMigrationRecoveryRequired)
        XCTAssertFalse(WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: restarted.storeURL))
        XCTAssertEqual(try restarted.startup(), .ready)
        XCTAssertTrue(restarted.keychain.added.isEmpty && !restarted.keychain.changedExistingItems)
        XCTAssertNotNil(try LegacySoraSecretResolver.resolve(account: account, keystore: restarted.keychain))
    }

    private func phraseAccountsSharingTheGlobalEntropy() throws
        -> (Installation, global: AccountItem, underPath: AccountItem, edwards: AccountItem, Data, WalletNetworkSnapshot) {
        let device = try Installation()
        let phrase15 = try phrase(entropy: 0x13, bytes: 20)
        let entropy = try HistoricalWriter.version1(phrase: phrase15, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("9753".utf8), with: KeystoreTag.pincode.rawValue)
        let seed = try SeedFactory().deriveSeed(from: phrase15, password: "").seed.miniSeed
        let pair = try SR25519KeypairFactory().createKeypairFromSeed(seed, chaincodeList: [])
        // The 1.x wallet, still backed only by `seedEntropy` (its scoped
        // copies were deferred).
        let global = AccountItem(address: try SS58AddressFactory().address(fromAccountId: pair.publicKey().rawData(),
            type: Chain.sora.addressType()), cryptoType: .sr25519, networkType: Chain.sora.addressType(),
            username: "Version 1 wallet", publicKeyData: pair.publicKey().rawData(),
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
        // The same phrase imported again under //1 and as ed25519: their
        // scoped entropy has the same bytes as `seedEntropy`.
        let underPath = try HistoricalWriter.phraseImport(phrase15, path: "//1", username: "Path", order: 1,
                                                          isSelected: false, keystore: device.keychain.base)
        let edwards = try HistoricalWriter.phraseImport(phrase15, cryptoType: .ed25519, username: "Ed", order: 2,
                                                        isSelected: false, keystore: device.keychain.base)
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.entropyTagForAddress(underPath.address)), entropy)
        let store = try device.networkStore()
        try WalletNetworkModelMigrator(keystore: device.keychain, store: store, settings: device.settings,
            lifecycleCoordinator: device.coordinator, recoveryGate: device.isolatedGate())
            .migrate(accounts: [global, underPath, edwards], selectedAddress: global.address)
        return (device, global, underPath, edwards, entropy, try XCTUnwrap(store.load()))
    }

    func testRemovingTheSamePhraseUnderAnotherPathOrTypeKeepsTheGlobalEntropy() throws {
        let (device, global, underPath, edwards, entropy, snapshot) = try phraseAccountsSharingTheGlobalEntropy()
        let accounts = [global, underPath, edwards]
        func plan(_ target: AccountItem) throws -> WalletExplicitRemovalPlan {
            try WalletExplicitRemovalIdentityPolicy.plan(accounts: accounts, expectedAccount: target,
                walletId: target.address, snapshot: snapshot, keystore: device.keychain,
                settings: device.settings, recoveryGate: device.isolatedGate())
        }
        for target in [underPath, edwards] {
            XCTAssertEqual(try plan(target),
                           WalletExplicitRemovalPlan(removesOwnKeyMaterial: true, removesRetainedLegacyEntropy: false))
            let keys = AddOnlyRecordingKeychain()
            for (tag, bytes) in try device.keychain.bytes() { try keys.base.addKey(bytes, with: tag) }
            try WalletExplicitRemovalIdentityPolicy.removeKeychainItems(plan: plan(target), address: target.address,
                isLastAccount: false, keystore: keys, settings: InMemorySettingsManager())
            XCTAssertEqual(try keys.base.fetchKey(for: KeystoreTag.legacyEntropy.rawValue), entropy)
            XCTAssertTrue(try keys.base.checkKey(for: "privateKey"))
            XCTAssertTrue(try keys.base.checkKey(for: KeystoreTag.pincode.rawValue))
            XCTAssertTrue(keys.deleted.allSatisfy { $0.hasPrefix(target.address + "-") }, "\(keys.deleted)")
        }
        // Only the account the global entropy derives owns it.
        XCTAssertEqual(try plan(global),
                       WalletExplicitRemovalPlan(removesOwnKeyMaterial: true, removesRetainedLegacyEntropy: true))
        XCTAssertTrue(try WalletExplicitRemovalIdentityPolicy.verify(accounts: accounts, expectedAccount: global,
            walletId: global.address, snapshot: snapshot, keystore: device.keychain, settings: device.settings,
            recoveryGate: device.isolatedGate()))
    }

    func testRemovingAReadOnlyAccountRemovesNoKeychainItem() throws {
        let device = try Installation()
        let usable = try HistoricalWriter.phraseImport(phrase12, username: "Usable", order: 0, isSelected: true,
                                                       keystore: device.keychain.base)
        // Keys present but for another key pair.
        let mismatched = try HistoricalWriter.phraseImport(phrase(entropy: 5, bytes: 16), username: "Mismatched",
            order: 1, isSelected: false, keystore: InMemoryKeychain())
        let foreign = try SR25519KeypairFactory().createKeypairFromSeed(Data(repeating: 9, count: 32), chaincodeList: [])
        try device.keychain.base.addKey(foreign.privateKey().rawData(),
                                        with: KeystoreTag.secretKeyTagForAddress(mismatched.address))
        // Keys missing (a new iPhone).
        let missing = try HistoricalWriter.phraseImport(phrase(entropy: 6, bytes: 16), username: "Missing",
            order: 2, isSelected: false, keystore: InMemoryKeychain())
        // Retained 1.x items that belong to none of them.
        try device.keychain.base.addKey(Data(repeating: 0x22, count: 20), with: KeystoreTag.legacyEntropy.rawValue)
        try device.keychain.base.addKey(Data("1470".utf8), with: KeystoreTag.pincode.rawValue)
        try KeySafetyStore.write([usable, mismatched, missing], to: device.storeURL)
        XCTAssertEqual(try device.startup(), .ready)
        let snapshot = try XCTUnwrap(device.networkStore().load())
        let accounts = [usable, mismatched, missing]
        func plan(_ target: AccountItem) throws -> WalletExplicitRemovalPlan {
            try WalletExplicitRemovalIdentityPolicy.plan(accounts: accounts, expectedAccount: target,
                walletId: target.address, snapshot: snapshot, keystore: device.keychain,
                settings: device.settings, recoveryGate: device.isolatedGate())
        }
        for target in [mismatched, missing] {
            XCTAssertEqual(try plan(target), .keepKeychain)
            for isLast in [false, true] {
                let keys = AddOnlyRecordingKeychain()
                for (tag, bytes) in try device.keychain.bytes() { try keys.base.addKey(bytes, with: tag) }
                try WalletExplicitRemovalIdentityPolicy.removeKeychainItems(plan: plan(target),
                    address: target.address, isLastAccount: isLast, keystore: keys, settings: InMemorySettingsManager())
                XCTAssertEqual(keys.deleted, [], "\(target.username) last: \(isLast)")
            }
        }
        // The usable account as the last one: its proven keys and the PIN go
        // (as before); the global entropy that is not its own stays.
        XCTAssertEqual(try plan(usable),
                       WalletExplicitRemovalPlan(removesOwnKeyMaterial: true, removesRetainedLegacyEntropy: false))
        let keys = AddOnlyRecordingKeychain()
        for (tag, bytes) in try device.keychain.bytes() { try keys.base.addKey(bytes, with: tag) }
        try WalletExplicitRemovalIdentityPolicy.removeKeychainItems(plan: plan(usable), address: usable.address,
            isLastAccount: true, keystore: keys, settings: InMemorySettingsManager())
        XCTAssertTrue(try keys.base.checkKey(for: KeystoreTag.legacyEntropy.rawValue))
        XCTAssertFalse(try keys.base.checkKey(for: KeystoreTag.pincode.rawValue))
        XCTAssertFalse(try keys.base.hasScopedSigningMaterial(for: usable.address))
        XCTAssertTrue(try keys.base.checkKey(for: KeystoreTag.secretKeyTagForAddress(mismatched.address)))
        // What the account screen reports for each.
        for (account, expected) in [(usable, WalletAccountKeyAvailability.available),
                                    (mismatched, .keysNotVerified), (missing, .keysMissing)] {
            XCTAssertEqual(try WalletAccountKeyAvailability.status(for: account, keystore: device.keychain,
                settings: device.settings, activeSnapshot: snapshot, recoveryGate: device.isolatedGate()), expected)
        }
        XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
    }

    func testRestoredAccountsWithAPathOrASeedGetASecretKeyForAppStore386() throws {
        let reference = InMemoryKeychain()
        let pathAccount = try HistoricalWriter.phraseImport(phrase12, path: "//1", username: "Path", order: 0,
                                                            isSelected: true, keystore: reference)
        let seed = Data(repeating: 52, count: 32)
        let seedAccount = try HistoricalWriter.seedImport(seed, cryptoType: .ed25519, username: "Seed", order: 1,
                                                          keystore: reference)
        let interrupted = try HistoricalWriter.phraseImport(phrase(entropy: 0x71, bytes: 16), path: "//2",
            username: "Interrupted", order: 2, isSelected: false, keystore: reference)
        let device = try Installation()
        try KeySafetyStore.write([pathAccount, seedAccount.replacingSelection(false), interrupted],
                                 to: device.storeURL)
        // An earlier 3.9.0 candidate restored this one with its phrase and
        // path only (no `-seed`, no `-secretKey`).
        for tag in [KeystoreTag.entropyTagForAddress(interrupted.address),
                    KeystoreTag.deriviationTagForAddress(interrupted.address)] {
            try device.keychain.base.addKey(try reference.fetchKey(for: tag), with: tag)
        }
        // New iPhone: the recovery screen restores the path account by phrase.
        device.settings.setWalletMigrationRecovery(reason: UserStorageMigrationError
            .privacySafeRecoveryDescription(for: UserStorageMigrationError.missingWalletSecret("x")))
        try device.migrator().restoreMissingEntropy(address: pathAccount.address, mnemonic: phrase12,
            derivationPath: "//1", baseURL: device.directory,
            lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.isolatedGate()))
        XCTAssertEqual(device.keychain.added, [KeystoreTag.deriviationTagForAddress(pathAccount.address),
            KeystoreTag.entropyTagForAddress(pathAccount.address), KeystoreTag.seedTagForAddress(pathAccount.address),
            KeystoreTag.secretKeyTagForAddress(pathAccount.address)])
        XCTAssertEqual(try device.startup(), .ready)
        // The startup backfill completed the interrupted one.
        XCTAssertTrue(try device.keychain.checkKey(for: KeystoreTag.secretKeyTagForAddress(interrupted.address)))
        XCTAssertTrue(try device.keychain.checkKey(for: KeystoreTag.seedTagForAddress(interrupted.address)))
        // In the app, the seed account is restored from its seed.
        let gate = device.isolatedGate()
        try device.migrator(gate: gate).restoreKeysForReadOnlyAccount(address: seedAccount.address,
            expectedAccount: nil, entropy: nil, rawSeed: seed, secret: nil, derivationPath: "",
            networkStore: device.networkStore(), lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate))
        XCTAssertTrue(try device.keychain.checkKey(for: KeystoreTag.secretKeyTagForAddress(seedAccount.address)))
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertFalse(device.keychain.changedExistingItems)
        for account in [pathAccount, seedAccount, interrupted] {
            for tag in [KeystoreTag.secretKeyTagForAddress(account.address), KeystoreTag.seedTagForAddress(account.address)] {
                if try reference.checkKey(for: tag) {
                    XCTAssertTrue(try device.keychain.checkKey(for: tag), tag)
                }
            }
        }
        // App Store 3.8.6 over this data keeps its settings and signs for all.
        let outcome = try AppStore386Launch.run(storeURL: device.storeURL, keystore: device.keychain.base,
                                                settings: device.settings)
        XCTAssertFalse(outcome.settingsWiped)
        for account in [pathAccount, seedAccount, interrupted] {
            XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain.base), account.username)
        }
    }

    func testImportingThePhraseOfAReadOnlyAccountRestoresItInPlace() throws {
        let original = try Installation()
        let first = try HistoricalWriter.phraseImport(phrase12, username: "First", order: 0, isSelected: true,
                                                      keystore: original.keychain.base)
        let secondPhrase = try phrase(entropy: 0x44, bytes: 16)
        let second = try HistoricalWriter.phraseImport(secondPhrase, username: "Second", order: 1, isSelected: false,
                                                       keystore: original.keychain.base)
        try KeySafetyStore.write([first, second], to: original.storeURL)
        XCTAssertEqual(try original.startup(), .ready)
        // New iPhone from an iCloud backup: files came back, keys did not.
        let restored = try Installation()
        try FileManager.default.removeItem(at: restored.directory)
        try FileManager.default.copyItem(at: original.directory, to: restored.directory)
        XCTAssertEqual(try restored.startup(), .ready)
        XCTAssertEqual(try WalletAccountKeyAvailability.status(for: second, keystore: restored.keychain,
            settings: restored.settings, activeSnapshot: restored.networkStore().load(),
            recoveryGate: restored.isolatedGate()), .keysMissing)
        let selection = try restored.selectedWalletSettings(accounts: [first, second])
        let result = try restored.importPhrase(secondPhrase, into: selection)
        XCTAssertEqual(result.address, second.address)
        XCTAssertEqual(result.username, "Second")
        XCTAssertTrue(result.isSelected)
        XCTAssertEqual(Set(restored.keychain.added), [KeystoreTag.secretKeyTagForAddress(second.address),
            KeystoreTag.entropyTagForAddress(second.address), KeystoreTag.seedTagForAddress(second.address)])
        XCTAssertFalse(restored.keychain.changedExistingItems)
        XCTAssertFalse(restored.settings.walletMigrationRecoveryRequired)
        XCTAssertNotNil(try LegacySoraSecretResolver.resolve(account: second, keystore: restored.keychain))
        let snapshot = try XCTUnwrap(restored.networkStore().load())
        XCTAssertEqual(snapshot.selectedWalletId, second.address)
        XCTAssertEqual(try WalletAccountKeyAvailability.status(for: second, keystore: restored.keychain,
            settings: restored.settings, activeSnapshot: snapshot, recoveryGate: restored.isolatedGate()), .available)
        // The same phrase again is a duplicate, as is any account with keys.
        XCTAssertThrowsError(try restored.importPhrase(secondPhrase, into: selection)) {
            guard case AccountCreateError.duplicated = $0 else { return XCTFail("\($0)") }
        }
        // A watch-only account is never given keys by an import.
        restored.settings.set(value: true, for: "wallet.watchOnly.\(first.address)")
        XCTAssertThrowsError(try restored.importPhrase(phrase12, into: selection)) {
            guard case AccountCreateError.duplicated = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertFalse(try restored.keychain.hasScopedSigningMaterial(for: first.address))
    }

    func testWelcomeBackFindsAOneXWalletBackedOnlyBySeedEntropy() throws {
        let device = try Installation()
        let entropy = try HistoricalWriter.version1(phrase: phrase(entropy: 0x12, bytes: 20),
                                                    keystore: device.keychain.base)
        let other = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("8642".utf8), with: KeystoreTag.pincode.rawValue)
        let before = try device.keychain.bytes()
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
        let inventory = try RetainedKeychainWalletDiscovery.inventory(keystore: device.keychain,
                                                                      recoveryGate: device.isolatedGate())
        let global = try XCTUnwrap(inventory.adoptable.first(where: \.usesGlobalEntropy))
        XCTAssertEqual(Set(inventory.adoptable.map(\.address)), [global.address, other.address])
        XCTAssertEqual(inventory.unprovableAddressCount, 0)
        let result = RetainedKeychainWalletDiscovery.restore(inventory.adoptable, keystore: device.keychain,
            selectedWalletSettings: try device.selectedWalletSettings(), lifecycleCoordinator: device.coordinator,
            recoveryGate: device.isolatedGate())
        XCTAssertEqual(Set(result.restored.map(\.address)), [global.address, other.address])
        XCTAssertEqual(Set(device.keychain.added), [KeystoreTag.secretKeyTagForAddress(global.address),
            KeystoreTag.entropyTagForAddress(global.address), KeystoreTag.seedTagForAddress(global.address)])
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.entropyTagForAddress(global.address)), entropy)
        XCTAssertFalse(device.keychain.changedExistingItems)
        for (tag, bytes) in before { XCTAssertEqual(try device.keychain.fetchKey(for: tag), bytes) }

        // A 1.x `privateKey` that `seedEntropy` does not derive: not offered.
        let mismatched = try Installation()
        try mismatched.keychain.base.addKey(Data(repeating: 0x33, count: 20), with: KeystoreTag.legacyEntropy.rawValue)
        try mismatched.keychain.base.addKey(Data(repeating: 1, count: 32), with: "privateKey")
        try HistoricalWriter.phraseImport(phrase12, keystore: mismatched.keychain.base)
        let mismatchedInventory = try RetainedKeychainWalletDiscovery.inventory(keystore: mismatched.keychain,
            recoveryGate: mismatched.isolatedGate())
        XCTAssertFalse(mismatchedInventory.adoptable.contains(where: \.usesGlobalEntropy))
        XCTAssertEqual(mismatchedInventory.unprovableAddressCount, 1)
    }

    /// 1.x items that do not prove themselves are "not a 1.x upgrade": the
    /// app goes to Welcome back (and from there to onboarding), not to a
    /// recovery screen that Set up again cannot leave.
    func testOneXKeysThatDoNotProveThemselvesLeadToWelcomeBack() throws {
        let device = try Installation()
        try device.keychain.base.addKey(Data(repeating: 0x33, count: 20), with: KeystoreTag.legacyEntropy.rawValue)
        try device.keychain.base.addKey(Data(repeating: 1, count: 32), with: "privateKey")
        try device.keychain.base.addKey(Data("1357".utf8), with: KeystoreTag.pincode.rawValue)
        let before = try device.keychain.bytes()
        XCTAssertFalse(try LegacyWalletUpgradePolicy.shouldDeferStorageMigration(storeExists: false,
            keystore: device.keychain, hasWatchOnlyWallet: false, snapshot: nil))
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        // From a recovery screen, Set up again leads to the same place.
        device.settings.setWalletMigrationRecovery(reason: "Some other integrity check")
        try WalletLocalStateSetAside.setAside(settings: device.settings,
            expectedMarker: WalletMigrationRecoveryMarker.capture(device.settings),
            paths: .init(storeURL: device.storeURL, applicationSupportURL: device.directory,
                         setAsideRootURL: device.directory.appendingPathComponent("WalletSetAside")),
            lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.isolatedGate()))
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
        XCTAssertEqual(try device.keychain.bytes(), before)
        XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
        // A 1.x install that proves itself still gets the explicit upgrade.
        let proven = try Installation()
        try HistoricalWriter.version1(phrase: phrase(entropy: 0x34, bytes: 20), keystore: proven.keychain.base)
        XCTAssertTrue(try LegacyWalletUpgradePolicy.shouldDeferStorageMigration(storeExists: false,
            keystore: proven.keychain, hasWatchOnlyWallet: false, snapshot: nil))
        XCTAssertEqual(try proven.rootDecision(selected: nil), [.legacyWalletUpgrade])
    }

    func testRepeatedUnverifiedFailuresKeepOnlyTheNewestSupersededAttempts() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try KeySafetyStore.write([account], to: device.storeURL)
        let keys = try device.keychain.bytes()
        let failing = try device.migrator(afterCopy: { _ in
            throw UserStorageMigrationError.backupVerificationFailed("synthetic")
        })
        XCTAssertEqual(WalletStorageStartup.run(settings: device.settings) {
            try failing.migrateAtStartup(lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.gate()),
                                         hasUnresolvedAccountCommit: { false })
        }, .recoveryRequired)
        for _ in 0..<6 {
            let marker = WalletMigrationRecoveryMarker.capture(device.settings)
            XCTAssertTrue(marker.isRetryableStartupFailure)
            XCTAssertThrowsError(try failing.resumeForStartupVerification(marker: marker))
        }
        let superseded = try FileManager.default.contentsOfDirectory(at:
            device.directory.appendingPathComponent("WalletMigrationSuperseded"), includingPropertiesForKeys: nil)
        XCTAssertEqual(superseded.count, UserStorageMigrator.retainedSupersededAttempts)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at:
            device.directory.appendingPathComponent("WalletMigrationSafety"), includingPropertiesForKeys: nil).count, 1)
        // The live store keeps its rows (only SQLite's WAL checkpoint touched it).
        XCTAssertEqual(try KeySafetyStore.rows(at: device.storeURL).map(\.address), [account.address])
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try device.keychain.bytes(), keys)
    }

    func testRestoringFoundWalletsSkipsExistingOnesAndContinuesPastAFailure() throws {
        let device = try Installation()
        let wallets = try [phrase12, phrase(entropy: 0x51, bytes: 16), phrase(entropy: 0x52, bytes: 16)].map {
            try HistoricalWriter.phraseImport($0, keystore: device.keychain.base)
        }
        try device.keychain.base.addKey(Data("5555".utf8), with: KeystoreTag.pincode.rawValue)
        let inventory = try RetainedKeychainWalletDiscovery.inventory(keystore: device.keychain,
                                                                      recoveryGate: device.isolatedGate())
        XCTAssertEqual(inventory.adoptable.count, 3)
        let existing = wallets[0]
        let failing = try XCTUnwrap(inventory.adoptable.first { $0.address != existing.address })
        let other = try XCTUnwrap(inventory.adoptable.first { $0.address != existing.address && $0 != failing })
        // One wallet is already in the wallet; another one's items changed
        // after the inventory, so its restore fails on its own.
        let selection = try device.selectedWalletSettings(accounts: [existing])
        let originalSeed = try device.keychain.fetchKey(for: KeystoreTag.seedTagForAddress(failing.address))
        try device.keychain.base.updateKey(Data(repeating: 9, count: 32),
                                           with: KeystoreTag.seedTagForAddress(failing.address))
        var result = RetainedKeychainWalletDiscovery.restore(inventory.adoptable, existing: [existing.address],
            keystore: device.keychain, selectedWalletSettings: selection, lifecycleCoordinator: device.coordinator,
            recoveryGate: device.isolatedGate())
        XCTAssertEqual(result.restored.map(\.address), [other.address])
        XCTAssertEqual(result.failedAddresses, [failing.address])
        XCTAssertNotNil(result.firstError)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
        // Retrying with the addresses already in the wallet excluded restores
        // only the one that is missing.
        try device.keychain.base.updateKey(originalSeed, with: KeystoreTag.seedTagForAddress(failing.address))
        let retry = try RetainedKeychainWalletDiscovery.inventory(keystore: device.keychain,
            excluding: [existing.address, other.address], recoveryGate: device.isolatedGate())
        XCTAssertEqual(retry.adoptable.map(\.address), [failing.address])
        result = RetainedKeychainWalletDiscovery.restore(retry.adoptable,
            existing: [existing.address, other.address], keystore: device.keychain, selectedWalletSettings: selection,
            lifecycleCoordinator: device.coordinator, recoveryGate: device.isolatedGate())
        XCTAssertEqual(result.restored.map(\.address), [failing.address])
        XCTAssertTrue(result.failedAddresses.isEmpty)
    }

    func testSetUpAgainUndoesItsMovesWhenOneFailsAndContinuesInTheSameFolder() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("1234".utf8), with: KeystoreTag.pincode.rawValue)
        try KeySafetyStore.write([account], to: device.storeURL)
        device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        XCTAssertEqual(try device.startup(), .ready)
        device.settings.setWalletMigrationRecovery(reason: "Some other integrity check")
        let marker = WalletMigrationRecoveryMarker.capture(device.settings)
        let keys = try device.keychain.bytes()
        let storeBytes = try Data(contentsOf: device.storeURL)
        let root = device.directory.appendingPathComponent("WalletSetAside")
        let paths = WalletLocalStateSetAside.Paths(storeURL: device.storeURL,
            applicationSupportURL: device.directory, setAsideRootURL: root)
        let coordinator = WalletLifecycleCoordinator(recoveryGate: device.isolatedGate())
        func networks() -> URL { device.directory.appendingPathComponent("SORA/WalletNetworks") }

        // 1. One move fails: the moves already done are undone.
        XCTAssertThrowsError(try WalletLocalStateSetAside.setAside(settings: device.settings, expectedMarker: marker,
            paths: paths, lifecycleCoordinator: coordinator, beforeMove: { source in
                if source.lastPathComponent == "WalletNetworks" { throw CocoaError(.fileWriteNoPermission) }
            }))
        XCTAssertEqual(try Data(contentsOf: device.storeURL), storeBytes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: networks().path))
        XCTAssertTrue(FileManager.default.fileExists(atPath:
            device.directory.appendingPathComponent("WalletMigrationSafety").path))
        XCTAssertTrue(device.settings.hasRetainedWalletSettings())
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(device.settings), marker)
        XCTAssertTrue((try? FileManager.default.contentsOfDirectory(atPath: root.path))?.isEmpty ?? true)

        // 2. A move cannot be undone either (something recreated the store
        // file meanwhile): the folder is marked incomplete and says so.
        var incomplete: URL?
        XCTAssertThrowsError(try WalletLocalStateSetAside.setAside(settings: device.settings, expectedMarker: marker,
            paths: paths, lifecycleCoordinator: coordinator, beforeMove: { source in
                if source.lastPathComponent == "WalletNetworks" {
                    try Data("recreated".utf8).write(to: device.storeURL)
                    throw CocoaError(.fileWriteNoPermission)
                }
            })) { error in
            guard case let WalletLocalStateSetAside.Failure.incomplete(folder) = error else {
                return XCTFail("\(error)")
            }
            incomplete = folder
        }
        let folder = try XCTUnwrap(incomplete)
        XCTAssertTrue(FileManager.default.fileExists(atPath:
            folder.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName).path))
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("CoreData/UserDataModel.sqlite")), storeBytes)
        XCTAssertTrue(device.settings.hasRetainedWalletSettings())
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(device.settings), marker)

        // 3. Trying again continues in the same folder and completes.
        let completed = try WalletLocalStateSetAside.setAside(settings: device.settings, expectedMarker: marker,
            paths: paths, lifecycleCoordinator: coordinator)
        XCTAssertEqual(completed.resolvingSymlinksInPath().path, folder.resolvingSymlinksInPath().path)
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            folder.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: device.storeURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: networks().path))
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("CoreData/UserDataModel.sqlite")), storeBytes)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).count, 1)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(try device.keychain.bytes(), keys)
        XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
    }

    func testJSONImportAdoptsRetainedItemsOfAWalletCreatedWithAPath() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, path: "//0", keystore: device.keychain.base)
        let secret = try device.keychain.fetchKey(for: KeystoreTag.secretKeyTagForAddress(account.address))
        let before = try device.keychain.bytes()
        let gate = device.isolatedGate()
        let factory = AccountOperationFactory(keystore: device.keychain, recoveryGate: gate)
        let imported = try device.insert(PreparedAccount(account: account, secretKey: secret, entropy: nil, seed: nil,
            derivationPath: nil, recoveryGate: gate), into: device.selectedWalletSettings(), factory: factory)
        XCTAssertEqual(imported.address, account.address)
        XCTAssertEqual(device.keychain.added, [])
        XCTAssertEqual(try device.keychain.bytes(), before)

        // Retained items under the path that do not derive this account are
        // a conflict: nothing is written and the next import still works.
        let conflicting = try Installation()
        try conflicting.keychain.base.addKey(Data("//0".utf8), with: KeystoreTag.deriviationTagForAddress(account.address))
        try conflicting.keychain.base.addKey(Data(repeating: 7, count: 16),
                                             with: KeystoreTag.entropyTagForAddress(account.address))
        let conflictingFactory = AccountOperationFactory(keystore: conflicting.keychain,
                                                         recoveryGate: conflicting.isolatedGate())
        let selection = try conflicting.selectedWalletSettings()
        XCTAssertThrowsError(try conflicting.insert(PreparedAccount(account: account, secretKey: secret, entropy: nil,
            seed: nil, derivationPath: nil, recoveryGate: conflicting.isolatedGate()), into: selection,
            factory: conflictingFactory)) {
            guard case AccountCreateError.retainedKeyConflict = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertEqual(conflicting.keychain.added, [])
        XCTAssertFalse(conflicting.settings.walletMigrationRecoveryRequired)
        XCTAssertNoThrow(try conflicting.importPhrase(phrase(entropy: 0x35, bytes: 16), into: selection))
    }

    func testTheEarlierPinIsKeptWhenOnboardingStartsSoFoundWalletsStayRestorable() throws {
        let device = try Installation()
        let first = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        let second = try HistoricalWriter.phraseImport(phrase(entropy: 0x61, bytes: 16), keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("1111".utf8), with: KeystoreTag.pincode.rawValue)
        XCTAssertTrue(WalletRecoveryStateProbe.retainedWalletsAfterSetup(keystore: device.keychain,
            existingAddresses: [], recoveryGate: device.isolatedGate()).isEmpty, "No copy of an earlier PIN yet")
        XCTAssertTrue(try WalletRetainedPinGate.preserveEarlierInstallPin(keystore: device.keychain))
        XCTAssertFalse(try WalletRetainedPinGate.preserveEarlierInstallPin(keystore: device.keychain))
        XCTAssertEqual(device.keychain.added, ["\(WalletRetainedPinGate.earlierInstallPinTagPrefix)1"])
        // Onboarding sets a new PIN over the old one; the user imports one wallet.
        try device.keychain.base.updateKey(Data("2222".utf8), with: KeystoreTag.pincode.rawValue)
        let selection = try device.selectedWalletSettings()
        XCTAssertEqual(try device.importPhrase(phrase12, into: selection).address, first.address)
        // The other wallet stays restorable, with the earlier PIN only.
        XCTAssertEqual(WalletRecoveryStateProbe.retainedWalletsAfterSetup(keystore: device.keychain,
            existingAddresses: [first.address], recoveryGate: device.isolatedGate()).map(\.address), [second.address])
        XCTAssertThrowsError(try WalletRetainedPinGate.verify("2222", keystore: device.keychain,
            settings: device.settings, scope: .afterSetup))
        XCTAssertNoThrow(try WalletRetainedPinGate.verify("1111", keystore: device.keychain,
            settings: device.settings, scope: .afterSetup))
        XCTAssertNoThrow(try WalletRetainedPinGate.verify("2222", keystore: device.keychain,
            settings: device.settings, scope: .welcomeBack))
        let inventory = try RetainedKeychainWalletDiscovery.inventory(keystore: device.keychain,
            excluding: [first.address], recoveryGate: device.isolatedGate())
        let result = RetainedKeychainWalletDiscovery.restore(inventory.adoptable, existing: [first.address],
            keystore: device.keychain, selectedWalletSettings: selection, lifecycleCoordinator: device.coordinator,
            recoveryGate: device.isolatedGate())
        XCTAssertEqual(result.restored.map(\.address), [second.address])
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("2222".utf8))
        XCTAssertEqual(device.keychain.updated, [])
        XCTAssertEqual(device.keychain.deleted, [])
    }

    func testAppStore386DriveBackupOfASixWordWalletRestores() throws {
        let short = try shortPhrase(words: 6)
        let reference = AddOnlyRecordingKeychain()
        let account = try HistoricalWriter.phraseImport(short, keystore: reference.base)
        let device = try Installation()
        try KeySafetyStore.write([account], to: device.storeURL)
        device.settings.setWalletMigrationRecovery(reason: UserStorageMigrationError
            .privacySafeRecoveryDescription(for: UserStorageMigrationError.missingWalletSecret("x")))
        let password = "backup-password-386"
        try WalletCloudBackupRecoveryService.restore(data: try appStore386Backup(address: account.address,
            phrase: short, password: password), password: password, account: account, migrator: device.migrator(),
            baseURL: device.directory, lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.isolatedGate()))
        // The short entropy, seed and secret, as App Store 3.8.6 stored them.
        XCTAssertEqual(try device.keychain.bytes(), try reference.bytes())
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try device.networkStore().load()?.wallets.first?.secretSource, .rawSeed)
        XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain.base))
        // Onboarding: a short backup phrase is accepted only for the
        // backup's own address; new imports never accept it.
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: short)
        let factory = AccountOperationFactory(keystore: AddOnlyRecordingKeychain(), recoveryGate: device.isolatedGate())
        let request = AccountCreationRequest(username: "Backup", type: .sora, derivationPath: "", cryptoType: .sr25519)
        let match = BaseAccountImportInteractor.requireAddress(account.address,
            of: factory.prepareAccountOperation(request: request, mnemonic: mnemonic))
        match.start()
        XCTAssertEqual(try match.extractResultData(throwing: BaseOperationError.parentOperationCancelled).account.address,
                       account.address)
        XCTAssertFalse(WalletMnemonicWordPolicy.retainedSoraWordCounts.contains(6))
        XCTAssertTrue(WalletMnemonicWordPolicy.knownAddressRestoreWordCounts.contains(6))
    }

    func testSigningErrorsSeparateMissingKeysFromKeysThatDoNotMatch() {
        for error in [SigningWrapperError.keysNotOnThisDevice, .keysNotVerified] {
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("iPhone"), message)
            XCTAssertFalse(message.lowercased().contains("reinstall"))
            XCTAssertFalse(message.lowercased().contains("delete"))
        }
        XCTAssertNotEqual(SigningWrapperError.keysNotOnThisDevice.localizedDescription,
                          SigningWrapperError.keysNotVerified.localizedDescription)
    }

    // MARK: Second review round

    private func spinRunLoop(until condition: () -> Bool, timeout: TimeInterval = 10) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    /// Welcome back's phrase, Google Drive and set-up actions run after
    /// launch routing has returned. Through the production factory, the Root
    /// module stays alive (`SoraWindow.rootModule`) and the action opens
    /// onboarding; before, the wireframe was already released and the tap
    /// did nothing.
    func testWelcomeBackActionsOpenOnboardingAfterLaunchRoutingReturns() throws {
        let device = try Installation()
        try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("135790".utf8), with: KeystoreTag.pincode.rawValue)
        let window = SoraWindow(frame: UIScreen.main.bounds)
        try autoreleasepool {
            let presenter = RootPresenterFactory.createPresenter(
                with: window, interactor: try device.rootInteractor(selected: nil),
                wireframe: RootWireframe(keystore: device.keychain, settings: device.settings))
            presenter.loadOnLaunch()
        }
        XCTAssertNotNil(window.rootModule)
        let welcome = try XCTUnwrap((window.rootViewController as? UINavigationController)?
            .viewControllers.first as? WalletWelcomeBackViewController)
        welcome.leaveForOnboarding()
        spinRunLoop { window.rootViewController is WelcomeBackgroundViewController }
        XCTAssertTrue(window.rootViewController is WelcomeBackgroundViewController)
        // Leaving kept a copy of the earlier PIN and marked this install's
        // PIN as not set yet.
        XCTAssertEqual(device.keychain.added, ["\(WalletRetainedPinGate.earlierInstallPinTagPrefix)1"])
        XCTAssertTrue(WalletPendingPinSetup.isPending(device.settings))
        XCTAssertFalse(device.keychain.changedExistingItems)
    }

    /// The 1.x upgrade confirmation and its import completion reach the Root
    /// module after launch routing has returned.
    func testLegacyUpgradeConfirmationRunsTheUpgradeAfterLaunchRoutingReturns() throws {
        let device = try Installation()
        try HistoricalWriter.version1(phrase: phrase(entropy: 0x12, bytes: 20), keystore: device.keychain.base)
        let importer = LegacyUpgradeImportSpy()
        let window = SoraWindow(frame: UIScreen.main.bounds)
        try autoreleasepool {
            let presenter = RootPresenterFactory.createPresenter(
                with: window, interactor: try device.rootInteractor(selected: nil, legacyImporter: importer),
                wireframe: RootWireframe(keystore: device.keychain, settings: device.settings))
            presenter.loadOnLaunch()
        }
        let confirmation = try XCTUnwrap((window.rootViewController as? UINavigationController)?
            .viewControllers.first as? LegacyWalletUpgradeViewController)
        confirmation.loadViewIfNeeded()
        var stack: [UIView] = [confirmation.view]
        var continueButton: UIButton?
        while let view = stack.popLast() {
            if let button = view as? UIButton,
               button.accessibilityIdentifier == RetainedMigrationEvidenceHarness.continueUpgradeAccessibilityIdentifier {
                continueButton = button
            }
            stack.append(contentsOf: view.subviews)
        }
        try XCTUnwrap(continueButton).sendActions(for: .touchUpInside)
        XCTAssertEqual(importer.requests.count, 1)
        XCTAssertEqual(importer.requests.first?.mnemonic.split(separator: " ").count, 15)
        // The completion reaches the module as well: a failure opens recovery.
        importer.completions.first?(.failure(WalletIntegrityError.legacyWalletUpgradeVerificationFailed))
        XCTAssertTrue((window.rootViewController as? UINavigationController)?.viewControllers.first
            is WalletRecoveryViewController)
        XCTAssertTrue(device.keychain.added.isEmpty)
        XCTAssertFalse(device.keychain.changedExistingItems)
    }

    /// Welcome back, then the phrase import commits, then the app stops
    /// before PIN setup: the next launch asks for a new PIN, not the earlier
    /// one. PIN setup then keeps the earlier PIN (already kept) and the other
    /// found wallet stays restorable with it.
    func testAStopBetweenTheImportAndPinSetupAfterWelcomeBackLeadsBackToPinSetup() throws {
        let device = try Installation()
        let retained = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        let other = try HistoricalWriter.phraseImport(phrase(entropy: 0x62, bytes: 16), keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("111111".utf8), with: KeystoreTag.pincode.rawValue)
        XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
        try WalletPendingPinSetup.leaveWelcomeBack(keystore: device.keychain, settings: device.settings)
        let imported = try device.importPhrase(phrase12, into: device.selectedWalletSettings())
        XCTAssertEqual(imported.address, retained.address)

        let restarted = try device.copy()
        XCTAssertEqual(try restarted.rootDecision(selected: imported), [.pincodeSetup])

        let saved = expectation(description: "PIN saved")
        let output = PinSetupOutputSpy()
        output.onSave = { saved.fulfill() }
        let interactor = PinSetupInteractor(secretManager: KeystoreSecretManager(restarted.keychain),
            settingsManager: restarted.settings, biometryAuth: KeySafetyNoBiometry(),
            config: ApplicationConfig.shared, earlierPinKeystore: restarted.keychain,
            recoveryGate: restarted.isolatedGate())
        interactor.presenter = output
        interactor.process(pin: "222222")
        wait(for: [saved], timeout: 10)
        XCTAssertTrue(output.errors.isEmpty)
        XCTAssertEqual(try restarted.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("222222".utf8))
        XCTAssertFalse(WalletPendingPinSetup.isPending(restarted.settings))
        XCTAssertEqual(try restarted.rootDecision(selected: imported), [.localAuthentication])
        // Only `pincode` was replaced; nothing was added (the copy existed).
        XCTAssertEqual(restarted.keychain.updated, [KeystoreTag.pincode.rawValue])
        XCTAssertEqual(restarted.keychain.deleted, [])
        XCTAssertEqual(restarted.keychain.added, [])
        XCTAssertNoThrow(try WalletRetainedPinGate.verify("111111", keystore: restarted.keychain,
            settings: restarted.settings, scope: .afterSetup))
        XCTAssertThrowsError(try WalletRetainedPinGate.verify("222222", keystore: restarted.keychain,
            settings: restarted.settings, scope: .afterSetup))
        XCTAssertEqual(WalletRecoveryStateProbe.retainedWalletsAfterSetup(keystore: restarted.keychain,
            existingAddresses: [imported.address], recoveryGate: restarted.isolatedGate()).map(\.address),
            [other.address])
    }

    /// Leaving Welcome back needs a stored copy of the earlier PIN. Every
    /// distinct PIN gets one (no limit); when the copy cannot be saved,
    /// Welcome back stays, PIN setup stops, and the earlier PIN is unchanged.
    func testTheEarlierPinMustBeKeptBeforeItCanBeReplacedWithoutALimit() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        for (index, pin) in ["111111", "222222", "333333", "444444"].enumerated() {
            try device.keychain.base.addKey(Data(pin.utf8),
                with: "\(WalletRetainedPinGate.earlierInstallPinTagPrefix)\(index + 1)")
        }
        try device.keychain.base.addKey(Data("555555".utf8), with: KeystoreTag.pincode.rawValue)
        try WalletPendingPinSetup.leaveWelcomeBack(keystore: device.keychain, settings: device.settings)
        XCTAssertEqual(device.keychain.added, ["\(WalletRetainedPinGate.earlierInstallPinTagPrefix)5"])
        try WalletPendingPinSetup.leaveWelcomeBack(keystore: device.keychain, settings: device.settings)
        XCTAssertEqual(device.keychain.added.count, 1, "An identical copy is not added twice")
        XCTAssertFalse(device.keychain.changedExistingItems)
        // Welcome back restore: the PIN of `pincode` keeps it; a PIN that only
        // matched an earlier copy asks for a new PIN first.
        XCTAssertTrue(try WalletRetainedPinGate.verify("555555", keystore: device.keychain, settings: device.settings))
        XCTAssertFalse(try WalletRetainedPinGate.verify("111111", keystore: device.keychain, settings: device.settings))
        WalletPendingPinSetup.settleAfterWelcomeBackRestore(matchedCurrentPin: true, settings: device.settings)
        XCTAssertEqual(try device.rootDecision(selected: account), [.localAuthentication])
        WalletPendingPinSetup.settleAfterWelcomeBackRestore(matchedCurrentPin: false, settings: device.settings)
        XCTAssertEqual(try device.rootDecision(selected: account), [.pincodeSetup])

        // A Keychain that cannot add: nothing continues.
        let failing = AddFailingKeychain()
        try HistoricalWriter.phraseImport(phrase12, keystore: failing.base)
        try failing.base.addKey(Data("777777".utf8), with: KeystoreTag.pincode.rawValue)
        let settings = InMemorySettingsManager()
        XCTAssertThrowsError(try WalletPendingPinSetup.leaveWelcomeBack(keystore: failing, settings: settings)) {
            XCTAssertEqual($0 as? WalletRetainedPinGate.Failure, .earlierPinNotKept)
        }
        XCTAssertFalse(WalletPendingPinSetup.isPending(settings))
        var continued = false
        let controller = WalletWelcomeBackViewController(keystore: failing, settings: settings,
            onContinueToOnboarding: { continued = true }, onWalletsRestored: {})
        controller.leaveForOnboarding()
        spinRunLoop(until: { continued }, timeout: 2)
        XCTAssertFalse(continued)
        XCTAssertFalse(WalletPendingPinSetup.isPending(settings))

        let output = PinSetupOutputSpy()
        let interactor = PinSetupInteractor(secretManager: KeystoreSecretManager(failing),
            settingsManager: settings, biometryAuth: KeySafetyNoBiometry(), config: ApplicationConfig.shared,
            earlierPinKeystore: failing, recoveryGate: WalletRecoveryCapabilityGate(settings: settings,
                unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false }))
        interactor.presenter = output
        interactor.process(pin: "888888")
        XCTAssertEqual(output.errors.compactMap { $0 as? WalletRetainedPinGate.Failure }, [.earlierPinNotKept])
        XCTAssertEqual(try failing.fetchKey(for: KeystoreTag.pincode.rawValue), Data("777777".utf8))
        XCTAssertEqual(WalletPinPrompt.message(for: WalletRetainedPinGate.Failure.earlierPinNotKept),
                       WalletUX.text("SORA could not save a copy of the PIN you used before. Nothing was changed. Try again."))
    }

    /// While this install's PIN is not set yet, or on Welcome back, returning
    /// from the background does not ask for the earlier install's PIN.
    func testNoResumePinIsAskedForWhileTheNewPinIsPendingOrOnWelcomeBack() {
        let keychain = InMemoryKeychain()
        try? keychain.addKey(Data("111111".utf8), with: KeystoreTag.pincode.rawValue)
        let settings = InMemorySettingsManager()
        var date = Date(timeIntervalSince1970: 1_000)
        let interactor = SecurityLayerInteractor(applicationHandler: ApplicationHandler(), settings: settings,
            keystore: keychain, pincodeDelay: 300, currentDate: { date })
        let output = SecurityLayerOutputSpy()
        interactor.presenter = output
        func backgroundAndReturn() {
            interactor.didReceiveWillResignActive(notification: Notification(name: UIApplication.willResignActiveNotification))
            date.addTimeInterval(301)
            interactor.didReceiveWillEnterForeground(notification: Notification(name: UIApplication.willEnterForegroundNotification))
        }
        WalletPendingPinSetup.begin(settings)
        backgroundAndReturn()
        XCTAssertEqual(output.authorizationRequests, 0)
        WalletPendingPinSetup.finish(settings)
        backgroundAndReturn()
        XCTAssertEqual(output.authorizationRequests, 1)

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController:
            WalletWelcomeBackViewController(keystore: keychain, settings: settings,
                                            onContinueToOnboarding: {}, onWalletsRestored: {}))
        var pinScreens = 0
        let wireframe = SecurityLayerWireframe(windowProvider: { window }, pinFactory: { _ in pinScreens += 1; return nil })
        wireframe.showAuthorization()
        XCTAssertNil(wireframe.authorizationWindow)
        XCTAssertEqual(pinScreens, 0)
    }

    /// A read error while the shared gate probed the migration namespace
    /// latched "unfinished or unverifiable". Once every attempt verifies as
    /// finished, startup proves the store and keys and clears it.
    func testAGateLatchedMigrationMarkerIsClearedOnceEveryAttemptVerifies() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try KeySafetyStore.write([account], to: device.storeURL)
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertFalse(WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: device.storeURL))
        let unreadable = WalletRecoveryCapabilityGate(settings: device.settings,
            unresolvedMigrationJournal: { true }, unresolvedWalletCommitJournal: { false })
        XCTAssertThrowsError(try unreadable.requireMutableWalletAccess())
        XCTAssertTrue(WalletMigrationRecoveryMarker.capture(device.settings).isDatabaseInterruption)
        let keys = try device.keychain.bytes()
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try device.keychain.bytes(), keys)
        XCTAssertFalse(device.keychain.changedExistingItems)

        // The same kind of marker before any database attempt existed.
        let early = try Installation()
        let earlyAccount = try HistoricalWriter.phraseImport(phrase12, keystore: early.keychain.base)
        try KeySafetyStore.write([earlyAccount], to: early.storeURL)
        early.settings.setWalletMigrationRecovery(reason: UserStorageMigrationError
            .privacySafeRecoveryDescription(for: UserStorageMigrationError.interruptedMigration))
        XCTAssertTrue(WalletMigrationRecoveryMarker.capture(early.settings).isDatabaseInterruption)
        XCTAssertEqual(try early.startup(), .ready)
        XCTAssertFalse(early.settings.walletMigrationRecoveryRequired)
        XCTAssertFalse(WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: early.storeURL))
        XCTAssertFalse(early.keychain.changedExistingItems)
    }

    /// A read that failed while the backup copy was being verified records
    /// `interrupted_migration`. That attempt never replaced the store: it is
    /// set aside and a fresh attempt runs, instead of every launch stopping.
    func testAnAttemptInterruptedWhileVerifyingItsBackupIsSetAsideAndRetried() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try KeySafetyStore.write([account], to: device.storeURL)
        let keys = try device.keychain.bytes()
        let failing = try device.migrator(afterCopy: { _ in throw UserStorageMigrationError.interruptedMigration })
        XCTAssertEqual(WalletStorageStartup.run(settings: device.settings) {
            try failing.migrateAtStartup(lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.gate()),
                                         hasUnresolvedAccountCommit: { false })
        }, .recoveryRequired)
        XCTAssertTrue(WalletMigrationRecoveryMarker.capture(device.settings).isDatabaseInterruption)
        let safety = device.directory.appendingPathComponent("WalletMigrationSafety")
        let failedAttempt = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: safety,
            includingPropertiesForKeys: nil).first)
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertTrue(FileManager.default.fileExists(atPath: device.directory
            .appendingPathComponent("WalletMigrationSuperseded")
            .appendingPathComponent(failedAttempt.lastPathComponent).path))
        XCTAssertFalse(WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: device.storeURL))
        XCTAssertEqual(try device.keychain.bytes(), keys)
    }

    /// Add account → Import with the phrase of an account that is in the
    /// wallet without its keys (new iPhone from an iCloud backup): the real
    /// presenter and interactor accept it and restore its keys in place.
    func testAddAccountImportRestoresTheKeysOfAReadOnlyAccount() throws {
        let original = try Installation()
        let first = try HistoricalWriter.phraseImport(phrase12, username: "First", order: 0, isSelected: true,
                                                      keystore: original.keychain.base)
        let secondPhrase = try phrase(entropy: 0x45, bytes: 16)
        let second = try HistoricalWriter.phraseImport(secondPhrase, username: "Second", order: 1, isSelected: false,
                                                       keystore: original.keychain.base)
        try KeySafetyStore.write([first, second], to: original.storeURL)
        XCTAssertEqual(try original.startup(), .ready)
        let restored = try Installation()
        try FileManager.default.removeItem(at: restored.directory)
        try FileManager.default.copyItem(at: original.directory, to: restored.directory)
        XCTAssertEqual(try restored.startup(), .ready)

        let facade = UserDataStorageTestFacade()
        let selection = try restored.selectedWalletSettings(accounts: [first, second], facade: facade)
        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            facade.createRepository(mapper: AnyCoreDataMapper(AccountItemMapper()))
        let interactor = AddAccountImportInteractor(
            accountOperationFactory: AccountOperationFactory(keystore: restored.keychain,
                                                             recoveryGate: restored.isolatedGate()),
            accountRepository: AnyDataProviderRepository(repository), operationManager: OperationManager(),
            settings: selection, keystoreImportService: KeystoreImportService(logger: Logger.shared),
            eventCenter: EventCenter(), lifecycleCoordinator: restored.coordinator)
        let presenter = AccountImportPresenter(sourceType: .mnemonic, config: ApplicationConfig.shared)
        let wireframe = AccountImportWireframeSpy()
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        presenter.setup()
        presenter.sourceViewModel?.inputHandler.changeValue(to: secondPhrase)
        presenter.proceed()
        spinRunLoop { wireframe.proceeded > 0 || !wireframe.errors.isEmpty }
        XCTAssertEqual(wireframe.proceeded, 1)
        XCTAssertTrue(wireframe.errors.isEmpty, "\(wireframe.errors)")

        // The name step imports through the same interactor.
        let imported = expectation(description: "imported")
        var result: Result<AccountItem, Error>?
        interactor.importAccountWithMnemonic(request: AccountImportMnemonicRequest(mnemonic: secondPhrase,
            username: "Name step", networkType: .sora, derivationPath: "", cryptoType: .sr25519)) {
            result = $0
            imported.fulfill()
        }
        wait(for: [imported], timeout: 20)
        let account = try XCTUnwrap(result).get()
        XCTAssertEqual(account.address, second.address)
        XCTAssertEqual(account.username, "Second")
        XCTAssertEqual(Set(restored.keychain.added), [KeystoreTag.secretKeyTagForAddress(second.address),
            KeystoreTag.entropyTagForAddress(second.address), KeystoreTag.seedTagForAddress(second.address)])
        XCTAssertFalse(restored.keychain.changedExistingItems)

        // Now that its keys are here, the same phrase is a duplicate again.
        presenter.proceed()
        spinRunLoop { !wireframe.errors.isEmpty }
        XCTAssertEqual(wireframe.proceeded, 1)
        guard case AccountCreateError.duplicated? = wireframe.errors.first as? AccountCreateError else {
            return XCTFail("\(wireframe.errors)")
        }
    }

    /// Google Drive lists keep an account recorded as backed up when its keys
    /// are not on this iPhone (that record comes back with an iCloud restore).
    func testDriveBackupListsKeepAccountsWhoseKeysAreNotOnThisIPhone() throws {
        let keychain = AddOnlyRecordingKeychain()
        let withKeys = try HistoricalWriter.phraseImport(phrase12, keystore: keychain.base)
        let keyless = try HistoricalWriter.phraseImport(phrase(entropy: 0x46, bytes: 16), keystore: InMemoryKeychain())
        let recorded = [withKeys.address, keyless.address]
        XCTAssertTrue(WalletDriveBackupList.hidesBackup(of: withKeys.address, backedUpAddresses: recorded,
                                                        keystore: keychain))
        XCTAssertFalse(WalletDriveBackupList.hidesBackup(of: keyless.address, backedUpAddresses: recorded,
                                                         keystore: keychain))
        XCTAssertFalse(WalletDriveBackupList.hidesBackup(of: withKeys.address, backedUpAddresses: [],
                                                         keystore: keychain))
        XCTAssertTrue(keychain.added.isEmpty)
    }
}

// MARK: - Second review round doubles

/// Reads work; every write fails (a Keychain that is busy or will not save).
private final class AddFailingKeychain: KeystoreProtocol {
    let base = InMemoryKeychain()
    func addKey(_ key: Data, with identifier: String) throws { throw KeystoreError.unexpectedFail }
    func updateKey(_ key: Data, with identifier: String) throws { throw KeystoreError.unexpectedFail }
    func fetchKey(for identifier: String) throws -> Data { try base.fetchKey(for: identifier) }
    func checkKey(for identifier: String) throws -> Bool { try base.checkKey(for: identifier) }
    func allKeyIdentifiers() throws -> [String] { try base.allKeyIdentifiers() }
    func deleteKey(for identifier: String) throws { throw KeystoreError.unexpectedFail }
}

/// `KeychainManager` over a test Keychain (`saveSecret` adds or updates).
private final class KeystoreSecretManager: SecretStoreManagerProtocol {
    let keystore: KeystoreProtocol
    init(_ keystore: KeystoreProtocol) { self.keystore = keystore }

    func loadSecret(for identifier: String, completionQueue: DispatchQueue,
                    completionBlock: @escaping (SecretDataRepresentable?) -> Void) {
        let data = try? keystore.fetchKey(for: identifier)
        completionQueue.async { completionBlock(data) }
    }

    func saveSecret(_ secret: SecretDataRepresentable, for identifier: String, completionQueue: DispatchQueue,
                    completionBlock: @escaping (Bool) -> Void) {
        var saved = false
        if let data = secret.asSecretData() { saved = (try? keystore.saveKey(data, with: identifier)) != nil }
        completionQueue.async { completionBlock(saved) }
    }

    func removeSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        completionQueue.async { completionBlock(false) }
    }

    func checkSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        let exists = checkSecret(for: identifier)
        completionQueue.async { completionBlock(exists) }
    }

    func checkSecret(for identifier: String) -> Bool { (try? keystore.checkKey(for: identifier)) ?? false }
}

private final class KeySafetyNoBiometry: BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType { .none }
    func authenticate(localizedReason: String, completionQueue: DispatchQueue,
                      completionBlock: @escaping (Bool) -> Void) {
        completionQueue.async { completionBlock(false) }
    }
}

private final class PinSetupOutputSpy: PinSetupInteractorOutputProtocol {
    var onSave: (() -> Void)?
    var errors: [Error] = []
    func didSavePin() { onSave?() }
    func didStartWaitingBiometryDecision(type: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void) {
        completionBlock(false)
    }
    func didChangeState(from: PinSetupInteractor.PinSetupState) {}
    func didReceiveConfigError(_ error: Error) { errors.append(error) }
}

private final class SecurityLayerOutputSpy: SecurityLayerInteractorOutputProtocol {
    var authorizationRequests = 0
    func didDecideSecurePresentation() {}
    func didDecideUnsecurePresentation() {}
    func didDecideRequestAuthorization() { authorizationRequests += 1 }
}

/// Records the 1.x upgrade's import request; the test completes it.
private final class LegacyUpgradeImportSpy: AccountImportInteractorInputProtocol {
    var requests: [AccountImportMnemonicRequest] = []
    var completions: [(Result<AccountItem, Error>?) -> Void] = []
    func setup() {}
    func importAccountWithMnemonic(request: AccountImportMnemonicRequest,
                                   completion: ((Result<AccountItem, Error>?) -> Void)?) {
        requests.append(request)
        if let completion { completions.append(completion) }
    }
    func importAccountWithSeed(request: AccountImportSeedRequest, completion: ((Result<AccountItem, Error>?) -> Void)?) {}
    func importAccountWithKeystore(request: AccountImportKeystoreRequest,
                                   completion: ((Result<AccountItem, Error>?) -> Void)?) {}
    func validateAccountWithMnemonic(request: AccountImportMnemonicRequest,
                                     completion: ((Result<AccountItem?, Error>?) -> Void)?) {}
    func validateAccountWithSeed(request: AccountImportSeedRequest,
                                 completion: ((Result<AccountItem?, Error>?) -> Void)?) {}
    func validateAccountWithKeystore(request: AccountImportKeystoreRequest,
                                     completion: ((Result<AccountItem?, Error>?) -> Void)?) {}
    func deriveMetadataFromKeystore(_ keystore: String) {}
    func importBackedupAccount(request: AccountImportBackedupRequest) {}
}

private final class AccountImportWireframeSpy: AccountImportWireframeProtocol {
    var proceeded = 0
    var errors: [Error] = []
    func proceed(from view: AccountImportViewProtocol?, sourceType: AccountImportSource, cryptoType: CryptoType,
                 networkType: Chain, sourceViewModel: InputViewModelProtocol, usernameViewModel: InputViewModelProtocol,
                 passwordViewModel: InputViewModelProtocol?, derivationPathViewModel: InputViewModelProtocol?) {
        proceeded += 1
    }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        errors.append(error)
        return true
    }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?,
                 completion: @escaping () -> Void) -> Bool {
        errors.append(error)
        return true
    }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) {}
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?,
                 completion: @escaping () -> Void) {}
    func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style,
                 from view: ControllerBackedProtocol?) {}
}

// MARK: - ik2-leftover-files (audit I3): a kill inside a file write

/// One installation exactly as a process death at one instant leaves it: the
/// files (hard links kept), the Keychain items and the settings.
private struct KilledInstallation {
    let label: String
    let directory: URL
    let keys: [String: Data]
    let settings: [String: Any]

    /// A fresh process over that state.
    func revive() throws -> Installation {
        let revived = try Installation()
        try FileManager.default.removeItem(at: revived.directory)
        try InterruptedWrite.copyTree(at: directory, to: revived.directory)
        for (tag, bytes) in keys { try revived.keychain.base.addKey(bytes, with: tag) }
        for (key, value) in settings { revived.settings.set(anyValue: value, for: key) }
        return revived
    }
}

private enum InterruptedWrite {
    /// Copies a directory tree as a kill leaves it: two names of one file
    /// stay two names of one file, and extended attributes (the simulator's
    /// file-protection class) are kept.
    static func copyTree(at source: URL, to destination: URL) throws {
        let manager = FileManager.default
        var firstCopies: [String: URL] = [:]
        func copyDirectory(_ from: URL, _ to: URL) throws {
            try manager.createDirectory(at: to, withIntermediateDirectories: true)
            for name in try manager.contentsOfDirectory(atPath: from.path) {
                let child = from.appendingPathComponent(name)
                let target = to.appendingPathComponent(name)
                var info = stat()
                guard lstat(child.path, &info) == 0 else { throw CocoaError(.fileReadUnknown) }
                switch info.st_mode & S_IFMT {
                case S_IFDIR:
                    try copyDirectory(child, target)
                case S_IFREG:
                    let identity = "\(info.st_dev):\(info.st_ino)"
                    if let first = firstCopies[identity] {
                        try manager.linkItem(at: first, to: target)
                    } else {
                        try manager.copyItem(at: child, to: target)
                        firstCopies[identity] = target
                    }
                default:
                    try manager.copyItem(at: child, to: target)
                }
            }
        }
        try copyDirectory(source, destination)
    }

    /// Every entry below `root` with a name only `DurableFileWriter` creates.
    static func helperFiles(under root: URL) -> [String] {
        guard let enumerator = FileManager.default.enumerator(atPath: root.path) else { return [] }
        return enumerator.compactMap { $0 as? String }.filter {
            DurableFileWriter.leftoverKind(ofEntryNamed: ($0 as NSString).lastPathComponent) != nil
        }.sorted()
    }

    static func names(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    /// Recursive: an observer may itself make a durable write.
    private static let lock = NSRecursiveLock()

    /// Runs `body` with an observer on every checkpoint the writer reaches
    /// below `root`. Writes of the host app in other folders are ignored.
    static func observing(below root: URL,
                          _ observer: @escaping (DurableFileWriter.Checkpoint, URL) throws -> Void,
                          during body: () throws -> Void) rethrows {
        let rootPath = root.resolvingSymlinksInPath().path
        DurableFileWriter.checkpointObserver = { checkpoint, directory in
            guard directory.resolvingSymlinksInPath().path.hasPrefix(rootPath) else { return }
            lock.lock()
            defer { lock.unlock() }
            try observer(checkpoint, directory)
        }
        defer { DurableFileWriter.checkpointObserver = nil }
        try body()
    }

    /// Runs `body` and returns what a kill would leave at every checkpoint
    /// of every durable write it makes in `device`.
    static func killStates(of device: Installation, label: String,
                           during body: () throws -> Void) throws -> [KilledInstallation] {
        var states: [KilledInstallation] = []
        var failure: Error?
        try observing(below: device.directory, { checkpoint, directory in
            guard failure == nil else { return }
            do {
                states.append(try capture(device,
                    label: "\(label) #\(states.count): \(checkpoint.rawValue) in \(directory.lastPathComponent)"))
            } catch {
                failure = error
            }
        }, during: body)
        if let failure { throw failure }
        return states
    }

    /// The installation as a kill at this instant leaves it.
    static func capture(_ device: Installation, label: String) throws -> KilledInstallation {
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("killed-\(UUID().uuidString)", isDirectory: true)
        try copyTree(at: device.directory, to: copy)
        var settings: [String: Any] = [:]
        for key in device.settings.allKeys() { settings[key] = device.settings.anyValue(for: key) }
        return KilledInstallation(label: label, directory: copy, keys: try device.keychain.bytes(),
                                  settings: settings)
    }

    /// One file of each kind the writer can leave, as written and as empty
    /// files, and as extra names of `published` when there is one.
    @discardableResult
    static func plantHelperFiles(in directory: URL, besides published: URL? = nil) throws -> [URL] {
        let manager = FileManager.default
        var planted: [URL] = []
        func name(_ prefix: String, _ suffix: String) -> URL {
            directory.appendingPathComponent("\(prefix)\(UUID().uuidString)\(suffix)")
        }
        for content in [Data("content of an interrupted write".utf8), Data()] {
            for url in [name(".durable-", ".tmp"), name(".durable-rollback-", ".anchor"),
                        name(".durable-rollback-", ".safety-anchor"), name(".durable-failed-", ".withdrawn")] {
                XCTAssertTrue(manager.createFile(atPath: url.path, contents: content))
                planted.append(url)
            }
        }
        if let published, manager.fileExists(atPath: published.path) {
            for url in [name(".durable-rollback-", ".anchor"), name(".durable-rollback-", ".safety-anchor")] {
                try manager.linkItem(at: published, to: url)
                planted.append(url)
            }
        }
        return planted
    }
}

/// App Store 3.8.6 (`354f176c`) `AccountOptionsInteractor.logoutAndClean()`
/// for an account that is not the last one, over this data:
///
///     let forgetOperation = accountRepository.saveOperation { [] } _: { [idToRemove] }
///     forgetOperation.completionBlock = { ... self?.cleanKeystore(leavingPin: true) }
///     // cleanKeystore(leavingPin: true): try? keystore.deleteEntropy(for: address)
///     countOperation.completionBlock = { ...
///         if let deleted = self?.account, deleted.isSelected {
///             SelectedWalletSettings.shared.save(value: accounts[0])
///
/// The row goes, `-entropy` goes, the first remaining account is selected
/// when the removed one was. 3.8.6 knows no network snapshot and no commit
/// journal, so neither is touched.
private enum AppStore386Removal {
    static func logoutAndClean(_ account: AccountItem, storeURL: URL, keystore: KeystoreProtocol) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try KeySafetyStore.model(.version2))
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                                       at: storeURL, options: nil)
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        var failure: Error?
        context.performAndWait {
            do {
                let rows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDAccountItem"))
                var remaining: [NSManagedObject] = []
                for row in rows {
                    if row.value(forKey: "identifier") as? String == account.address {
                        context.delete(row)
                    } else {
                        remaining.append(row)
                    }
                }
                remaining.sort {
                    (($0.value(forKey: "order") as? NSNumber)?.intValue ?? 0) <
                        (($1.value(forKey: "order") as? NSNumber)?.intValue ?? 0)
                }
                if account.isSelected, let first = remaining.first {
                    for row in remaining { row.setValue(row === first, forKey: "isSelected") }
                }
                try context.save()
            } catch {
                failure = error
            }
        }
        if let failure { throw failure }
        try HistoricalWriter.appStore386RemoveAccount(account.address, keystore: keystore)
    }
}

/// The Keychain as seen by a process that dies after `survivingAdds` more
/// items were added: from then on no call reaches the Keychain, not even the
/// cleanup an error path would run.
private final class DyingKeychain: KeystoreProtocol {
    private let base: KeystoreProtocol
    private var survivingAdds: Int
    private(set) var isDead = false

    init(base: KeystoreProtocol, survivingAdds: Int) {
        self.base = base
        self.survivingAdds = survivingAdds
    }

    private func requireAlive() throws {
        if isDead { throw KeystoreError.unexpectedFail }
    }

    func addKey(_ key: Data, with identifier: String) throws {
        try requireAlive()
        guard survivingAdds > 0 else {
            isDead = true
            throw KeystoreError.unexpectedFail
        }
        survivingAdds -= 1
        try base.addKey(key, with: identifier)
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        try requireAlive()
        try base.updateKey(key, with: identifier)
    }

    func fetchKey(for identifier: String) throws -> Data {
        try requireAlive()
        return try base.fetchKey(for: identifier)
    }

    func checkKey(for identifier: String) throws -> Bool {
        try requireAlive()
        return try base.checkKey(for: identifier)
    }

    func allKeyIdentifiers() throws -> [String] {
        try requireAlive()
        return try base.allKeyIdentifiers()
    }

    func deleteKey(for identifier: String) throws {
        try requireAlive()
        try base.deleteKey(for: identifier)
    }
}

final class WalletInterruptedWriteTests: XCTestCase {
    private var scratch: [URL] = []

    override func tearDown() {
        DurableFileWriter.checkpointObserver = nil
        for url in scratch { try? FileManager.default.removeItem(at: url) }
        scratch = []
        super.tearDown()
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ik2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        scratch.append(directory)
        return directory
    }

    private func upgradedTwoAccountDevice() throws -> (Installation, AccountItem, AccountItem) {
        let device = try Installation()
        let first = try HistoricalWriter.phraseImport(phrase12, username: "First", order: 0, isSelected: true,
                                                      keystore: device.keychain.base)
        let second = try HistoricalWriter.phraseImport(try phrase(entropy: 0x44, bytes: 16), username: "Second",
                                                       order: 1, isSelected: false, keystore: device.keychain.base)
        try KeySafetyStore.write([first, second], to: device.storeURL)
        return (device, first, second)
    }

    /// A fresh process over `state` reaches a ready wallet, with and without
    /// the explicit startup sweep, and leaves no helper file anywhere.
    private func assertNextLaunchCompletes(_ state: KilledInstallation, accounts: [AccountItem],
                                           file: StaticString = #filePath, line: UInt = #line) throws {
        scratch.append(state.directory)
        for sweepsFirst in [true, false] {
            let label = "\(state.label), sweep first: \(sweepsFirst)"
            let revived = try state.revive()
            let keysBefore = try revived.keychain.bytes()
            XCTAssertEqual(try revived.startup(sweepsHelperFilesFirst: sweepsFirst), .ready, label,
                           file: file, line: line)
            XCTAssertFalse(revived.settings.walletMigrationRecoveryRequired, label, file: file, line: line)
            XCTAssertEqual(InterruptedWrite.helperFiles(under: revived.directory), [], label, file: file, line: line)
            XCTAssertFalse(WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: revived.storeURL),
                           label, file: file, line: line)
            XCTAssertEqual(try WalletAccountCommitJournalStore(baseURL: revived.directory,
                recoveryGate: revived.isolatedGate()).unresolved().count, 0, label, file: file, line: line)
            let snapshot = try XCTUnwrap(revived.networkStore().load(), label, file: file, line: line)
            XCTAssertEqual(Set(snapshot.wallets.map(\.id)), Set(accounts.map(\.address)), label,
                           file: file, line: line)
            let snapshots = try InterruptedWrite.names(in: revived.directory.appendingPathComponent("SORA/WalletNetworks"))
                .filter { $0.hasPrefix("wallet-network-") }
            XCTAssertLessThanOrEqual(snapshots.count, 8, label, file: file, line: line)
            for account in accounts {
                XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: revived.keychain), label,
                              file: file, line: line)
            }
            // No existing Keychain item was changed or removed.
            XCTAssertFalse(revived.keychain.changedExistingItems, label, file: file, line: line)
            for (tag, bytes) in keysBefore {
                XCTAssertEqual(try revived.keychain.fetchKey(for: tag), bytes, label, file: file, line: line)
            }
            // The launch after that one finds nothing left to do.
            XCTAssertEqual(try revived.startup(sweepsHelperFilesFirst: false), .ready, label, file: file, line: line)
        }
    }

    // MARK: 1. The writer and its helper files

    func testOnlyTheWritersOwnNamesAreHelperFiles() {
        let id = UUID().uuidString
        XCTAssertEqual(DurableFileWriter.leftoverKind(ofEntryNamed: ".durable-\(id).tmp"), .temporary)
        XCTAssertEqual(DurableFileWriter.leftoverKind(ofEntryNamed: ".durable-rollback-\(id).anchor"), .rollbackAnchor)
        XCTAssertEqual(DurableFileWriter.leftoverKind(ofEntryNamed: ".durable-rollback-\(id).safety-anchor"),
                       .safetyAnchor)
        XCTAssertEqual(DurableFileWriter.leftoverKind(ofEntryNamed: ".durable-failed-\(id).withdrawn"), .withdrawn)
        for name in ["active.json", "journal.json", "wallet-network-\(id).json", "wallet-account-\(id).json",
                     "sora2-signed-v1.json", ".hidden", ".durable-", ".durable-.tmp", ".durable-\(id)",
                     ".durable-\(id.lowercased()).tmp", ".durable-\(id).tmp.json", "x.durable-\(id).tmp",
                     ".durable-\(id)-\(id).tmp", ".durable-capability-root-residue.anchor",
                     ".durable-rollback-\(id).tmp", ".durable-failed-\(id).anchor", "durable-\(id).tmp"] {
            XCTAssertNil(DurableFileWriter.leftoverKind(ofEntryNamed: name), name)
        }
    }

    func testSweepRemovesHelperFilesAndNothingElse() throws {
        let directory = try makeDirectory()
        let published = directory.appendingPathComponent("journal.json")
        try Data("published".utf8).write(to: published)
        let hidden = directory.appendingPathComponent(".hidden")
        try Data("not the writer's".utf8).write(to: hidden)
        let planted = try InterruptedWrite.plantHelperFiles(in: directory, besides: published)
        XCTAssertEqual(planted.count, 10)
        // Entries with a helper name that the writer cannot have made.
        let linkName = directory.appendingPathComponent(".durable-\(UUID().uuidString).tmp")
        try FileManager.default.createSymbolicLink(at: linkName, withDestinationURL: published)
        let folderName = directory.appendingPathComponent(".durable-rollback-\(UUID().uuidString).anchor")
        try FileManager.default.createDirectory(at: folderName, withIntermediateDirectories: false)

        // The strict listing leaves out nothing but the writer's own files.
        let listed = try DurableFileWriter.contentsIgnoringLeftovers(
            of: directory, fileManager: .default, includingPropertiesForKeys: nil)
        XCTAssertEqual(Set(listed.map(\.lastPathComponent)),
                       ["journal.json", ".hidden", linkName.lastPathComponent, folderName.lastPathComponent])
        // That listing has swept already; a sweep now finds only the two.
        XCTAssertEqual(DurableFileWriter.sweepLeftovers(in: directory),
                       DurableFileWriter.LeftoverSweep(removed: 0, kept: 2, deferredToActiveWrite: false))
        XCTAssertEqual(try Data(contentsOf: published), Data("published".utf8))
        XCTAssertEqual(try Data(contentsOf: hidden), Data("not the writer's".utf8))
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: linkName.path), published.path)
        var info = stat()
        XCTAssertEqual(lstat(published.path, &info), 0)
        XCTAssertEqual(info.st_nlink, 1, "the extra names of the published file are gone")

        // Counted when the sweep itself removes them.
        let again = try InterruptedWrite.plantHelperFiles(in: directory, besides: published)
        XCTAssertEqual(DurableFileWriter.sweepLeftovers(in: directory),
                       DurableFileWriter.LeftoverSweep(removed: again.count, kept: 2, deferredToActiveWrite: false))
        // A missing directory is nothing to sweep.
        XCTAssertEqual(DurableFileWriter.sweepLeftovers(in: directory.appendingPathComponent("absent")),
                       DurableFileWriter.LeftoverSweep())
    }

    func testAWriteInProgressIsNeverSweptAndNeverFailsAListing() throws {
        let directory = try makeDirectory()
        let target = directory.appendingPathComponent("journal.json")
        try DurableFileWriter.write(Data("old".utf8), to: target, fileManager: .default,
                                    protection: .completeUntilFirstUserAuthentication)
        var seen: [DurableFileWriter.Checkpoint] = []
        try InterruptedWrite.observing(below: directory, { checkpoint, _ in
            seen.append(checkpoint)
            let namesBefore = try InterruptedWrite.names(in: directory)
            XCTAssertFalse(InterruptedWrite.helperFiles(under: directory).isEmpty, checkpoint.rawValue)
            // Another thread's sweep or strict listing at this instant.
            var sweep = DurableFileWriter.LeftoverSweep()
            var listed: [String] = []
            let other = Thread {
                sweep = DurableFileWriter.sweepLeftovers(in: directory)
                listed = ((try? DurableFileWriter.contentsIgnoringLeftovers(
                    of: directory, fileManager: .default, includingPropertiesForKeys: nil)) ?? [])
                    .map(\.lastPathComponent)
            }
            let done = DispatchSemaphore(value: 0)
            let waiter = Thread { other.start(); while !other.isFinished { usleep(500) }; done.signal() }
            waiter.start()
            done.wait()
            XCTAssertEqual(sweep, DurableFileWriter.LeftoverSweep(removed: 0, kept: 0, deferredToActiveWrite: true),
                           checkpoint.rawValue)
            XCTAssertEqual(listed, ["journal.json"], checkpoint.rawValue)
            XCTAssertEqual(try InterruptedWrite.names(in: directory), namesBefore, checkpoint.rawValue)
        }, during: {
            try DurableFileWriter.write(Data("new".utf8), to: target, fileManager: .default,
                                        protection: .completeUntilFirstUserAuthentication)
        })
        XCTAssertEqual(seen, [.temporaryFileCreated, .temporaryFileWritten, .rollbackAnchorLinked,
                              .rollbackAnchorSynchronized, .published, .publicationSynchronized,
                              .displacedOriginalRemoved])
        XCTAssertEqual(try Data(contentsOf: target), Data("new".utf8))
        XCTAssertEqual(try InterruptedWrite.names(in: directory), ["journal.json"])
        // Once the write has returned, the directory can be swept again.
        XCTAssertFalse(DurableFileWriter.sweepLeftovers(in: directory).deferredToActiveWrite)
    }

    func testAKillAtAnyStepOfAWriteLeavesThePublishedFileWholeAndOnlySweepableFiles() throws {
        for replacesExisting in [false, true] {
            let directory = try makeDirectory()
            let target = directory.appendingPathComponent("active.json")
            if replacesExisting {
                try DurableFileWriter.write(Data("old".utf8), to: target, fileManager: .default,
                                            protection: .completeUntilFirstUserAuthentication)
            }
            var states: [(DurableFileWriter.Checkpoint, URL)] = []
            try InterruptedWrite.observing(below: directory, { checkpoint, _ in
                let copy = try self.makeDirectory()
                try FileManager.default.removeItem(at: copy)
                try InterruptedWrite.copyTree(at: directory, to: copy)
                states.append((checkpoint, copy))
            }, during: {
                try DurableFileWriter.write(Data("new".utf8), to: target, fileManager: .default,
                                            protection: .completeUntilFirstUserAuthentication)
            })
            XCTAssertEqual(states.count, replacesExisting ? 7 : 4)
            var kindsSeen = Set<DurableFileWriter.LeftoverKind>()
            for (checkpoint, killed) in states {
                let label = "\(checkpoint.rawValue), replaces existing: \(replacesExisting)"
                let published = killed.appendingPathComponent("active.json")
                let before = try? Data(contentsOf: published)
                // The published name holds the whole old or the whole new file.
                if replacesExisting {
                    XCTAssertTrue(before == Data("old".utf8) || before == Data("new".utf8), label)
                } else {
                    XCTAssertTrue(before == nil || before == Data("new".utf8), label)
                }
                let helpers = InterruptedWrite.helperFiles(under: killed)
                helpers.compactMap(DurableFileWriter.leftoverKind(ofEntryNamed:)).forEach { kindsSeen.insert($0) }
                let sweep = DurableFileWriter.sweepLeftovers(in: killed)
                XCTAssertEqual(sweep, DurableFileWriter.LeftoverSweep(removed: helpers.count, kept: 0,
                                                                      deferredToActiveWrite: false), label)
                XCTAssertEqual(try InterruptedWrite.names(in: killed), before == nil ? [] : ["active.json"], label)
                XCTAssertEqual(try? Data(contentsOf: published), before, label)
                // The interrupted write can simply be made again.
                try DurableFileWriter.write(Data("retry".utf8), to: published, fileManager: .default,
                                            protection: .completeUntilFirstUserAuthentication)
                XCTAssertEqual(try Data(contentsOf: published), Data("retry".utf8), label)
                XCTAssertEqual(try InterruptedWrite.names(in: killed), ["active.json"], label)
            }
            XCTAssertEqual(kindsSeen, replacesExisting ? [.temporary, .rollbackAnchor] : [.temporary])
        }
    }

    func testAnErrorAtAnyStepOfAWriteLeavesNoHelperFileAndAWholePublishedFile() throws {
        struct InjectedFailure: Error {}
        for replacesExisting in [false, true] {
            for failing in DurableFileWriter.Checkpoint.allCases {
                let directory = try makeDirectory()
                let target = directory.appendingPathComponent("active.json")
                if replacesExisting {
                    try DurableFileWriter.write(Data("old".utf8), to: target, fileManager: .default,
                                                protection: .completeUntilFirstUserAuthentication)
                }
                var reached = false
                var later: [DurableFileWriter.Checkpoint] = []
                var thrown: Error?
                do {
                    try InterruptedWrite.observing(below: directory, { checkpoint, _ in
                        if checkpoint == failing, !reached {
                            reached = true
                            throw InjectedFailure()
                        }
                        if reached { later.append(checkpoint) }
                    }, during: {
                        try DurableFileWriter.write(Data("new".utf8), to: target, fileManager: .default,
                                                    protection: .completeUntilFirstUserAuthentication)
                    })
                } catch {
                    thrown = error
                }
                let label = "\(failing.rawValue), replaces existing: \(replacesExisting), then \(later.map(\.rawValue))"
                // Whatever happened, the directory holds no helper file.
                XCTAssertEqual(InterruptedWrite.helperFiles(under: directory), [], label)
                let content = try? Data(contentsOf: target)
                guard reached else {
                    // A step this kind of write does not have.
                    XCTAssertNil(thrown, label)
                    XCTAssertEqual(content, Data("new".utf8), label)
                    continue
                }
                if failing == .displacedOriginalRemoved {
                    // The write was committed before this step; it reports success.
                    XCTAssertNil(thrown, label)
                    XCTAssertEqual(content, Data("new".utf8), label)
                } else {
                    XCTAssertNotNil(thrown, label)
                    // A failed write leaves the old file (or no file) in place.
                    XCTAssertEqual(content, replacesExisting ? Data("old".utf8) : nil, label)
                    XCTAssertEqual(try InterruptedWrite.names(in: directory),
                                   replacesExisting ? ["active.json"] : [], label)
                }
                // And the same write succeeds when it is made again.
                try DurableFileWriter.write(Data("retry".utf8), to: target, fileManager: .default,
                                            protection: .completeUntilFirstUserAuthentication)
                XCTAssertEqual(try Data(contentsOf: target), Data("retry".utf8), label)
                XCTAssertEqual(try InterruptedWrite.names(in: directory), ["active.json"], label)
            }
        }
    }

    func testAnErrorWhileAFailedWriteIsRolledBackLeavesNoHelperFile() throws {
        struct InjectedFailure: Error {}
        // The publication fails, and then the rollback (or the withdrawal of
        // a new file) fails as well, at each of its steps.
        for replacesExisting in [false, true] {
            for second in [DurableFileWriter.Checkpoint.safetyAnchorLinked, .rolledBack, .failedPublicationWithdrawn] {
                let directory = try makeDirectory()
                let target = directory.appendingPathComponent("active.json")
                if replacesExisting {
                    try DurableFileWriter.write(Data("old".utf8), to: target, fileManager: .default,
                                                protection: .completeUntilFirstUserAuthentication)
                }
                var reachedSecond = false
                XCTAssertThrowsError(try InterruptedWrite.observing(below: directory, { checkpoint, _ in
                    if checkpoint == .publicationSynchronized { throw InjectedFailure() }
                    if checkpoint == second {
                        reachedSecond = true
                        throw InjectedFailure()
                    }
                }, during: {
                    try DurableFileWriter.write(Data("new".utf8), to: target, fileManager: .default,
                                                protection: .completeUntilFirstUserAuthentication)
                }))
                let label = "\(second.rawValue), replaces existing: \(replacesExisting), reached: \(reachedSecond)"
                XCTAssertEqual(InterruptedWrite.helperFiles(under: directory), [], label)
                // The published name holds a whole file: the old one, or the
                // new one when the rollback itself could not be completed
                // (what a kill at that instant leaves too).
                let content = try? Data(contentsOf: target)
                if replacesExisting {
                    XCTAssertTrue(content == Data("old".utf8) || content == Data("new".utf8), label)
                } else {
                    XCTAssertNil(content, label)
                }
                try DurableFileWriter.write(Data("retry".utf8), to: target, fileManager: .default,
                                            protection: .completeUntilFirstUserAuthentication)
                XCTAssertEqual(try InterruptedWrite.names(in: directory), ["active.json"], label)
            }
        }
    }

    // MARK: 2. Each strict folder with each kind of helper file

    func testPlantedHelperFilesInEveryWalletFolderAreGoneAfterStartup() throws {
        for sweepsFirst in [true, false] {
            let (device, first, second) = try upgradedTwoAccountDevice()
            XCTAssertEqual(try device.startup(), .ready)
            // A journal and a pending-transaction record exist, so each
            // folder has a published file to plant extra names of.
            let journals = try WalletAccountCommitJournalStore(baseURL: device.directory,
                                                               recoveryGate: device.isolatedGate())
            var commit = try journals.begin(walletId: "cnAnAccountAddedEarlier",
                                            existingWalletIds: [first.address, second.address])
            for stage in [WalletAccountCommitStage.secretsPersisted, .coreDataCommitted,
                          .networkModelActivated, .activated] {
                commit = try journals.advance(commit, to: stage)
            }
            let pending = try Sora2PendingSubmissionStore(baseURL: device.directory)
            _ = try pending.stage(account: first.address, hash: "0x" + String(repeating: "ab", count: 32))
            let keysBefore = try device.keychain.bytes()

            let sora = device.directory.appendingPathComponent("SORA", isDirectory: true)
            let attempt = try XCTUnwrap(try FileManager.default.contentsOfDirectory(
                at: device.directory.appendingPathComponent("WalletMigrationSafety"),
                includingPropertiesForKeys: nil).first)
            let networks = sora.appendingPathComponent("WalletNetworks")
            let commits = sora.appendingPathComponent("WalletAccountCommits")
            let transactions = sora.appendingPathComponent("PendingTransactions")
            let journal = try XCTUnwrap(try FileManager.default.contentsOfDirectory(
                at: commits, includingPropertiesForKeys: nil).first)
            var planted: [URL] = []
            planted += try InterruptedWrite.plantHelperFiles(in: networks,
                                                             besides: networks.appendingPathComponent("active.json"))
            planted += try InterruptedWrite.plantHelperFiles(in: commits, besides: journal)
            planted += try InterruptedWrite.plantHelperFiles(
                in: transactions, besides: transactions.appendingPathComponent("sora2-signed-v1.json"))
            planted += try InterruptedWrite.plantHelperFiles(in: attempt,
                                                             besides: attempt.appendingPathComponent("journal.json"))
            planted += try InterruptedWrite.plantHelperFiles(
                in: attempt.appendingPathComponent("legacy-store"),
                besides: attempt.appendingPathComponent("legacy-store/backup-manifest.json"))
            planted += try InterruptedWrite.plantHelperFiles(in: attempt.appendingPathComponent("staging"))
            XCTAssertEqual(planted.count, 58)

            let accounts = [first, second].map(\.address)
            let label = "sweep first: \(sweepsFirst)"
            XCTAssertEqual(try device.startup(sweepsHelperFilesFirst: sweepsFirst), .ready, label)
            XCTAssertFalse(device.settings.walletMigrationRecoveryRequired, label)
            if !sweepsFirst {
                // Without the explicit sweep each folder is cleaned by its
                // own check, when that check runs.
                XCTAssertFalse(WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: device.storeURL))
                _ = try pending.all()
                // "staging" is read only while an attempt is unfinished.
                XCTAssertEqual(InterruptedWrite.helperFiles(under: attempt).filter { !$0.hasPrefix("staging/") },
                               [], label)
            } else {
                XCTAssertEqual(InterruptedWrite.helperFiles(under: device.directory), [], label)
            }
            XCTAssertEqual(InterruptedWrite.helperFiles(under: sora), [], label)
            XCTAssertFalse(WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: device.storeURL), label)
            XCTAssertEqual(Set(try XCTUnwrap(device.networkStore().load()).wallets.map(\.id)), Set(accounts), label)
            XCTAssertEqual(try WalletAccountCommitJournalStore(baseURL: device.directory,
                recoveryGate: device.isolatedGate()).unresolved().count, 0, label)
            // Sending works: the next record is staged.
            _ = try pending.stage(account: first.address, hash: "0x" + String(repeating: "cd", count: 32))
            XCTAssertEqual(try pending.all().count, 2, label)
            XCTAssertEqual(try device.keychain.bytes(), keysBefore, label)
            XCTAssertTrue(try AppStore386Launch.canSign(first, keystore: device.keychain), label)
        }
    }
}

extension WalletInterruptedWriteTests {
    private func snapshotNames(_ device: Installation) throws -> [String] {
        try InterruptedWrite.names(in: device.directory.appendingPathComponent("SORA/WalletNetworks"))
            .filter { $0.hasPrefix("wallet-network-") }
    }

    private func keyStatus(_ account: AccountItem, on device: Installation) throws -> WalletAccountKeyAvailability {
        try WalletAccountKeyAvailability.status(for: account, keystore: device.keychain, settings: device.settings,
            activeSnapshot: device.networkStore().load(), recoveryGate: device.isolatedGate())
    }

    private func transactionHash(_ byte: UInt8) -> String {
        "0x" + String(repeating: String(format: "%02x", byte), count: 32)
    }

    // MARK: 3. A kill at any step, then a fresh start

    func testAKillAtAnyStepOfTheFirstLaunchAfterTheUpgradeIsCompletedByTheNextLaunch() throws {
        let (device, first, second) = try upgradedTwoAccountDevice()
        let states = try InterruptedWrite.killStates(of: device, label: "first launch") {
            XCTAssertEqual(try device.startup(), .ready)
        }
        // Six writes in the migration attempt and two in WalletNetworks.
        XCTAssertGreaterThanOrEqual(states.count, 32)
        XCTAssertTrue(states.contains { !InterruptedWrite.helperFiles(under: $0.directory).isEmpty })
        // Among them the state the audit names: the first snapshot is
        // written and its pointer is not.
        XCTAssertTrue(states.contains { state in
            let names = (try? InterruptedWrite.names(
                in: state.directory.appendingPathComponent("SORA/WalletNetworks"))) ?? []
            return names.contains { $0.hasPrefix("wallet-network-") } && !names.contains("active.json")
        })
        for state in states {
            try assertNextLaunchCompletes(state, accounts: [first, second])
        }
    }

    func testAKillAtAnyStepOfAnAccountSwitchOrRemovalIsCompletedByTheNextLaunch() throws {
        let (device, first, second) = try upgradedTwoAccountDevice()
        XCTAssertEqual(try device.startup(), .ready)
        let store = try device.networkStore()
        // Fill the folder to its bound of eight snapshots. From here on every
        // activation passes through nine before it prunes.
        for index in 0 ..< 8 {
            try store.selectWallet(walletId: index % 2 == 0 ? second.address : first.address,
                                   expectedAccounts: [first, second])
        }
        XCTAssertEqual(try snapshotNames(device).count, 8)
        var states = try InterruptedWrite.killStates(of: device, label: "switch") {
            try store.selectWallet(walletId: second.address, expectedAccounts: [first, second])
        }
        XCTAssertTrue(states.contains { state in
            let names = (try? InterruptedWrite.names(
                in: state.directory.appendingPathComponent("SORA/WalletNetworks"))) ?? []
            return names.filter { $0.hasPrefix("wallet-network-") }.count == 9
        })
        // A removal records itself in the snapshot before the row is deleted.
        states += try InterruptedWrite.killStates(of: device, label: "removal") {
            try store.recordExplicitRemoval(walletId: second.address,
                                            expectedWalletIds: [first.address, second.address],
                                            selectedWalletId: second.address)
        }
        XCTAssertGreaterThanOrEqual(states.count, 22)
        for state in states {
            try assertNextLaunchCompletes(state, accounts: [first, second])
        }
    }

    func testAKillAtAnyStepOfAnAccountJournalWriteLeavesAReadableJournal() throws {
        let directory = try makeDirectory()
        let gate = WalletRecoveryCapabilityGate(settings: InMemorySettingsManager(),
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        let journals = try WalletAccountCommitJournalStore(baseURL: directory, recoveryGate: gate)
        var states: [(String, URL)] = []
        var commit: WalletAccountCommitJournal?
        try InterruptedWrite.observing(below: directory, { checkpoint, _ in
            let copy = try self.makeDirectory()
            try FileManager.default.removeItem(at: copy)
            try InterruptedWrite.copyTree(at: directory, to: copy)
            states.append((checkpoint.rawValue, copy))
        }, during: {
            var journal = try journals.begin(walletId: "cnNewAccount", existingWalletIds: ["cnExisting"])
            for stage in [WalletAccountCommitStage.secretsPersisted, .coreDataCommitted,
                          .networkModelActivated, .activated] {
                journal = try journals.advance(journal, to: stage)
            }
            commit = journal
        })
        XCTAssertEqual(commit?.stage, .activated)
        // One new journal file, then four replacements.
        XCTAssertEqual(states.count, 4 + 4 * 7)
        for (label, killed) in states {
            // A fresh process reads the folder without an error: no journal
            // yet, or the one journal at a whole earlier or later stage.
            let revived = try WalletAccountCommitJournalStore(baseURL: killed, recoveryGate: gate)
            let found = try revived.journalsForLegacyRecovery()
            XCTAssertLessThanOrEqual(found.count, 1, label)
            XCTAssertTrue(found.allSatisfy { $0.walletId == "cnNewAccount" }, label)
            XCTAssertEqual(InterruptedWrite.helperFiles(under: killed), [], label)
        }
    }

    // MARK: 4. Snapshot states of an interrupted activation

    func testAFirstSnapshotWithoutItsPointerIsCompletedAndOtherPointerlessStatesStillFail() throws {
        let (device, first, second) = try upgradedTwoAccountDevice()
        XCTAssertEqual(try device.startup(), .ready)
        let networks = device.directory.appendingPathComponent("SORA/WalletNetworks")
        let pointer = networks.appendingPathComponent("active.json")
        let expected = try XCTUnwrap(device.networkStore().load())
        let pointerBytes = try Data(contentsOf: pointer)
        XCTAssertEqual(try snapshotNames(device).count, 1)
        let snapshotFile = networks.appendingPathComponent(try XCTUnwrap(snapshotNames(device).first))

        // The first activation wrote its snapshot and died before the pointer.
        try FileManager.default.removeItem(at: pointer)
        XCTAssertEqual(try device.networkStore().load(), expected)
        XCTAssertEqual(try Data(contentsOf: pointer), pointerBytes)
        try FileManager.default.removeItem(at: pointer)
        XCTAssertEqual(try device.startup(sweepsHelperFilesFirst: false), .ready)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(try Data(contentsOf: pointer), pointerBytes)
        XCTAssertEqual(Set(try XCTUnwrap(device.networkStore().load()).wallets.map(\.id)),
                       [first.address, second.address])

        // Two snapshots and no pointer is not a state an interrupted
        // activation leaves: nothing is guessed and nothing is written.
        let copy = networks.appendingPathComponent("wallet-network-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: snapshotFile, to: copy)
        try FileManager.default.removeItem(at: pointer)
        XCTAssertThrowsError(try device.networkStore().load()) {
            guard case WalletNetworkMigrationError.snapshotVerificationFailed = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: pointer.path))
        try FileManager.default.removeItem(at: copy)

        // One snapshot that does not decode is not adopted either.
        let snapshotBytes = try Data(contentsOf: snapshotFile)
        try Data("not a snapshot".utf8).write(to: snapshotFile)
        XCTAssertThrowsError(try device.networkStore().load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: pointer.path))
        try snapshotBytes.write(to: snapshotFile)
        XCTAssertEqual(try device.networkStore().load(), expected)
    }

    // MARK: 5. An account removed in App Store 3.8.6 after this version ran

    func testAnAccountRemovedInAppStore386IsRecordedAsRemovedAndTheOthersOpen() throws {
        for removesSelected in [false, true] {
            for latchedByAnEarlierBuild in [false, true] {
                let label = "removes selected: \(removesSelected), latched: \(latchedByAnEarlierBuild)"
                let (device, first, second) = try upgradedTwoAccountDevice()
                XCTAssertEqual(try device.startup(), .ready, label)
                XCTAssertEqual(try device.networkStore().load()?.wallets.count, 2, label)
                let removed = removesSelected ? first : second
                let kept = removesSelected ? second : first

                // App Store 3.8.6 runs over this data again and the user
                // removes an account there.
                try AppStore386Removal.logoutAndClean(removed, storeURL: device.storeURL,
                                                      keystore: device.keychain.base)
                XCTAssertEqual(try KeySafetyStore.rows(at: device.storeURL).map(\.address), [kept.address], label)
                XCTAssertEqual(try AppStore386Launch.run(storeURL: device.storeURL, keystore: device.keychain.base,
                                                         settings: device.settings).selected?.address,
                               kept.address, label)
                let keys = try device.keychain.bytes()
                XCTAssertNil(keys[KeystoreTag.entropyTagForAddress(removed.address)], label)
                XCTAssertNotNil(keys[KeystoreTag.secretKeyTagForAddress(removed.address)], label)
                if latchedByAnEarlierBuild {
                    // What 3.9.0 builds before this fix recorded here, on
                    // every launch.
                    device.settings.setWalletMigrationRecovery(reason: UserStorageMigrationError
                        .privacySafeRecoveryDescription(for: WalletNetworkMigrationError
                            .legacyIdentityMismatch(removed.address)))
                }

                // Back in this version: the wallet opens.
                XCTAssertEqual(try device.startup(), .ready, label)
                XCTAssertFalse(device.settings.walletMigrationRecoveryRequired, label)
                let snapshot = try XCTUnwrap(device.networkStore().load(), label)
                XCTAssertEqual(snapshot.wallets.map(\.id), [kept.address], label)
                XCTAssertEqual(snapshot.selectedWalletId, kept.address, label)
                XCTAssertTrue(snapshot.accounts.allSatisfy { $0.walletId == kept.address }, label)
                XCTAssertTrue(try AppStore386Launch.canSign(kept, keystore: device.keychain), label)
                XCTAssertEqual(try keyStatus(kept, on: device), .available, label)
                // The removed account's items are exactly what 3.8.6 left.
                XCTAssertEqual(try device.keychain.bytes(), keys, label)
                XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems, label)
                // The snapshot that listed it is kept; the next launch has
                // nothing more to record.
                XCTAssertGreaterThanOrEqual(try snapshotNames(device).count, 2, label)
                XCTAssertEqual(try device.startup(), .ready, label)
                XCTAssertEqual(try device.networkStore().load(), snapshot, label)
            }
        }
    }

    // MARK: 6. Records of unfinished transactions

    func testAKillAtAnyStepOfATransactionRecordWriteNeverBlocksTheNextSend() throws {
        let directory = try makeDirectory()
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        _ = try store.stage(account: "cnAccount", hash: transactionHash(0xa1))
        var states: [(String, URL)] = []
        try InterruptedWrite.observing(below: directory, { checkpoint, _ in
            let copy = try self.makeDirectory()
            try FileManager.default.removeItem(at: copy)
            try InterruptedWrite.copyTree(at: directory, to: copy)
            states.append((checkpoint.rawValue, copy))
        }, during: {
            _ = try store.stage(account: "cnAccount", hash: self.transactionHash(0xb2))
        })
        XCTAssertEqual(states.count, 7)
        XCTAssertTrue(states.contains { !InterruptedWrite.helperFiles(under: $0.1).isEmpty })
        for (label, killed) in states {
            // A fresh process over that folder.
            XCTAssertTrue(PendingTransactionRecords.isReadable(baseURL: killed), label)
            let revived = try Sora2PendingSubmissionStore(baseURL: killed)
            let before = try revived.all().count
            XCTAssertTrue(before == 1 || before == 2, label)
            _ = try revived.stage(account: "cnAccount", hash: transactionHash(0xc3))
            XCTAssertEqual(try revived.all().count, before + 1, label)
            XCTAssertEqual(InterruptedWrite.helperFiles(under: killed), [], label)
        }
    }

    func testAWriteOfAnotherJournalInProgressDoesNotRefuseASend() throws {
        let directory = try makeDirectory()
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        let folder = directory.appendingPathComponent("SORA/PendingTransactions")
        _ = try store.stage(account: "cnAccount", hash: transactionHash(0xa1))
        let other = folder.appendingPathComponent("polkamarkt-v1.json")
        try DurableFileWriter.write(Data("[]".utf8), to: other, fileManager: .default,
                                    protection: .completeUntilFirstUserAuthentication)
        var staged = 0
        var busy = false
        try InterruptedWrite.observing(below: directory, { _, _ in
            guard !busy else { return }
            busy = true
            defer { busy = false }
            XCTAssertFalse(InterruptedWrite.helperFiles(under: folder).isEmpty)
            staged += 1
            _ = try store.stage(account: "cnAccount", hash: self.transactionHash(0xb0 + UInt8(staged)))
            XCTAssertEqual(try store.all().count, 1 + staged)
        }, during: {
            try DurableFileWriter.write(Data("[ ]".utf8), to: other, fileManager: .default,
                                        protection: .completeUntilFirstUserAuthentication)
        })
        XCTAssertEqual(staged, 7)
        XCTAssertEqual(try Data(contentsOf: other), Data("[ ]".utf8))
        XCTAssertEqual(try InterruptedWrite.names(in: folder), ["polkamarkt-v1.json", "sora2-signed-v1.json"])
    }

    func testUnreadableTransactionRecordsShowRecoveryAndCanBeSetAside() throws {
        let (device, first, second) = try upgradedTwoAccountDevice()
        XCTAssertEqual(try device.startup(), .ready)
        let store = try Sora2PendingSubmissionStore(baseURL: device.directory)
        _ = try store.stage(account: first.address, hash: transactionHash(0xa1))
        let folder = device.directory.appendingPathComponent("SORA/PendingTransactions")
        let journal = folder.appendingPathComponent("sora2-signed-v1.json")
        let keys = try device.keychain.bytes()
        let root = device.directory.appendingPathComponent("WalletSetAside")
        let coordinator = WalletLifecycleCoordinator(recoveryGate: device.isolatedGate())

        for (index, breakage) in ["an entry this version does not know", "a journal that does not decode"]
            .enumerated() {
            if index == 0 {
                try Data("a later version's journal".utf8).write(
                    to: folder.appendingPathComponent("sora2-signed-v2.json"))
            } else {
                try Data("not a journal".utf8).write(to: journal)
            }
            let before = try Dictionary(uniqueKeysWithValues: InterruptedWrite.names(in: folder).map {
                ($0, try Data(contentsOf: folder.appendingPathComponent($0)))
            })

            // Every send is refused...
            XCTAssertThrowsError(try store.stage(account: first.address, hash: transactionHash(0xb2)), breakage)
            XCTAssertFalse(PendingTransactionRecords.isReadable(baseURL: device.directory), breakage)
            // ...so the next launch says so on the recovery screen, where
            // "Try again" is offered together with the action that fixes it.
            XCTAssertEqual(try device.startup(), .recoveryRequired, breakage)
            XCTAssertTrue(WalletMigrationRecoveryMarker.capture(device.settings).isRetryableStartupFailure, breakage)
            let diagnostic = try XCTUnwrap(WalletStartupDiagnostic.current(device.settings), breakage)
            XCTAssertEqual(diagnostic.phase, .pendingTransactions, breakage)
            XCTAssertEqual(diagnostic.userMessage, WalletUX.text("SORA cannot read its records of transactions that were still being confirmed, so it cannot safely start a new one. Your accounts, keys and funds are not affected. You can set these records aside below. Nothing is deleted."))
            let options = WalletRecoveryStateProbe.recovery(migrator: try device.migrator(),
                keystore: device.keychain, settings: device.settings,
                pendingTransactionsBaseURL: device.directory).options
            XCTAssertTrue(options.canSetAsideTransactionRecords, breakage)
            XCTAssertTrue(options.canRetry, breakage)
            XCTAssertTrue(options.hasForwardActionBesidesRetry, breakage)
            XCTAssertEqual(try device.startup(), .recoveryRequired, "Try again alone cannot pass: \(breakage)")

            // The action: the records are moved, nothing is deleted.
            let moved = try XCTUnwrap(PendingTransactionRecords.setAside(applicationSupportURL: device.directory,
                setAsideRootURL: root, lifecycleCoordinator: coordinator), breakage)
            let movedFolder = moved.appendingPathComponent("PendingTransactions")
            XCTAssertEqual(try Dictionary(uniqueKeysWithValues: InterruptedWrite.names(in: movedFolder).map {
                ($0, try Data(contentsOf: movedFolder.appendingPathComponent($0)))
            }), before, breakage)
            XCTAssertEqual(try InterruptedWrite.names(in: folder), [], breakage)
            XCTAssertTrue(PendingTransactionRecords.isReadable(baseURL: device.directory), breakage)

            // "Try again" now passes, and sending works with the store that
            // was created before the folder moved.
            XCTAssertEqual(try device.startup(), .ready, breakage)
            XCTAssertFalse(device.settings.walletMigrationRecoveryRequired, breakage)
            _ = try store.stage(account: first.address, hash: transactionHash(0xc3 + UInt8(index)))
            XCTAssertEqual(try store.all().count, 1, breakage)

            // Accounts, keys and the wallet database are as they were.
            XCTAssertEqual(try device.keychain.bytes(), keys, breakage)
            XCTAssertEqual(Set(try XCTUnwrap(device.networkStore().load()).wallets.map(\.id)),
                           [first.address, second.address], breakage)
            XCTAssertEqual(try KeySafetyStore.rows(at: device.storeURL).map(\.address),
                           [first.address, second.address], breakage)
            XCTAssertTrue(try AppStore386Launch.canSign(first, keystore: device.keychain), breakage)
        }
        XCTAssertEqual(try InterruptedWrite.names(in: root).count, 2)
        // Nothing to move is not an error.
        try FileManager.default.removeItem(at: folder)
        XCTAssertNil(try PendingTransactionRecords.setAside(applicationSupportURL: device.directory,
            setAsideRootURL: root, lifecycleCoordinator: coordinator))
        XCTAssertTrue(PendingTransactionRecords.isReadable(baseURL: device.directory))
    }

    func testTheRecoveryScreenOffersToSetTheRecordsAsideOnlyWhenTheyCannotBeRead() throws {
        func descendants(_ view: UIView) -> [UIView] { view.subviews + view.subviews.flatMap(descendants) }
        func recordsButton(_ controller: UIViewController) throws -> UIButton {
            try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
                .first { $0.accessibilityIdentifier == "wallet-recovery-set-aside-transaction-records" })
        }
        func options(unreadable: Bool) -> WalletRecoveryOptions {
            WalletRecoveryState.recovery(retryable: true, accountsMissingKeys: 0, accountsWithPhrase: 0,
                                         retainedPinUsable: false, transactionRecordsUnreadable: unreadable).options
        }
        let controller = WalletRecoveryViewController(reason: "fixture", onRetry: {}, onSetAside: {})
        controller.loadViewIfNeeded()
        XCTAssertTrue(try recordsButton(controller).isHidden)
        controller.apply(options(unreadable: true))
        XCTAssertFalse(try recordsButton(controller).isHidden)
        XCTAssertTrue(try recordsButton(controller).isEnabled)
        XCTAssertEqual(try recordsButton(controller).title(for: .normal),
                       WalletUX.text("Set aside unfinished transaction records"))
        controller.apply(options(unreadable: false))
        XCTAssertTrue(try recordsButton(controller).isHidden)
        // Where "Try again" is not available (a recovery screen shown inside
        // the app), the action that needs it is not shown either.
        let passive = WalletRecoveryViewController(reason: "fixture")
        passive.loadViewIfNeeded()
        passive.apply(options(unreadable: true))
        XCTAssertTrue(try recordsButton(passive).isHidden)

        // The body names the action this state offers, not a wallet restore.
        let settings = InMemorySettingsManager()
        XCTAssertEqual(WalletStorageStartup.run(settings: settings, maximumAttempts: 1) {
            try WalletStartupDiagnostic.check(.pendingTransactions) {
                throw PendingTransactionJournalNamespace.Failure.invalidNamespace
            }
        }, .recoveryRequired)
        let diagnostic = try XCTUnwrap(WalletStartupDiagnostic.current(settings))
        XCTAssertEqual(diagnostic.phase, .pendingTransactions)
        let records = WalletRecoveryViewController(reason: "fixture", diagnostic: diagnostic, onRetry: {},
                                                   onSetAside: {})
        records.loadViewIfNeeded()
        let body = try XCTUnwrap(descendants(records.view).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == "wallet-recovery-body" }?.text)
        XCTAssertTrue(body.contains(diagnostic.userMessage))
        XCTAssertTrue(body.contains(WalletUX.text("If setting the records aside does not help, contact SORA support with the app version shown below. Never share your recovery phrase.")))
        XCTAssertFalse(body.contains(WalletUX.text("SORA stopped before changing anything and did not delete or replace any wallet data. Try again, restore with your recovery phrase or Google Drive backup, or contact SORA support with the app version shown below. Never share your recovery phrase.")))

        // Every new text is in the English and the Japanese table.
        for key in [
            "Set aside unfinished transaction records",
            "Set aside unfinished transaction records?",
            "SORA will move its records of transactions that were still being confirmed to a separate folder on this iPhone. Nothing is deleted, and your accounts, keys and funds are not changed. SORA will no longer be able to tell you whether your most recent transaction went through, so check your activity before you send it again.",
            "Set aside",
            "Could not set the records aside",
            "If setting the records aside does not help, contact SORA support with the app version shown below. Never share your recovery phrase.",
            "SORA cannot read its records of transactions that were still being confirmed, so it cannot safely start a new one. Your accounts, keys and funds are not affected. You can set these records aside below. Nothing is deleted.",
        ] {
            for language in ["en", "ja"] {
                let table = try XCTUnwrap(Bundle(path: try XCTUnwrap(
                    Bundle.main.path(forResource: language, ofType: "lproj"))))
                let text = table.localizedString(forKey: key, value: "\u{1}missing", table: "Localizable")
                XCTAssertNotEqual(text, "\u{1}missing", "\(language): \(key)")
                XCTAssertFalse(text.isEmpty, "\(language): \(key)")
                if language == "ja" { XCTAssertNotEqual(text, key, key) }
            }
        }
    }

    // MARK: 7. The three multi-step writes of N6

    func testAKillDuringTheRestoreOfAShortPhraseLeavesAnAccountTheNextLaunchCompletes() throws {
        let address = "cnAnyAddress"
        let entropyTag = KeystoreTag.entropyTagForAddress(address)
        let seedTag = KeystoreTag.seedTagForAddress(address)
        let secretTag = KeystoreTag.secretKeyTagForAddress(address)
        let seed = Data(repeating: 2, count: 32), secret = Data(repeating: 3, count: 64)
        // A phrase that derives everything goes first; a 3/6/9-word entropy
        // derives nothing, so the seed that proves the account goes first.
        XCTAssertEqual(UserStorageMigrator.restoreWriteOrder(address: address,
            entropy: Data(repeating: 1, count: 16), rawSeed: seed, secret: secret).map(\.1),
            [entropyTag, seedTag, secretTag])
        for shortBytes in [4, 8, 12] {
            XCTAssertEqual(UserStorageMigrator.restoreWriteOrder(address: address,
                entropy: Data(repeating: 1, count: shortBytes), rawSeed: seed, secret: secret).map(\.1),
                [seedTag, entropyTag, secretTag])
        }

        for words in [3, 6, 9] {
            for survivingAdds in [1, 2] {
                let label = "\(words) words, dies after \(survivingAdds) Keychain write(s)"
                let short = try shortPhrase(words: words)
                let original = try Installation()
                let account = try HistoricalWriter.phraseImport(short, keystore: original.keychain.base)
                try KeySafetyStore.write([account], to: original.storeURL)
                XCTAssertEqual(try original.startup(), .ready, label)
                // A new iPhone: the files came back, the keys did not.
                let restored = try Installation()
                try FileManager.default.removeItem(at: restored.directory)
                try FileManager.default.copyItem(at: original.directory, to: restored.directory)
                XCTAssertEqual(try restored.startup(), .ready, label)
                XCTAssertEqual(try keyStatus(account, on: restored), .keysMissing, label)

                // The user restores with the phrase and the process dies
                // between two Keychain writes.
                let dying = DyingKeychain(base: restored.keychain, survivingAdds: survivingAdds)
                let store = try restored.networkStore()
                let migrator = UserStorageMigrator(targetVersion: .version2, storeURL: restored.storeURL,
                    modelDirectory: UserStorageParams.modelDirectory, keystore: dying, settings: restored.settings,
                    fileManager: .default, recoveryGate: restored.isolatedGate(),
                    availableCapacity: { _ in Int64.max }, loadWalletNetworkSnapshot: { try store.load() })
                XCTAssertThrowsError(try migrator.restoreKeysForReadOnlyAccount(address: account.address,
                    mnemonic: short, derivationPath: "", networkStore: store,
                    lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: restored.isolatedGate())), label)
                XCTAssertTrue(dying.isDead, label)
                XCTAssertEqual(restored.keychain.added, Array([KeystoreTag.seedTagForAddress(account.address),
                    KeystoreTag.entropyTagForAddress(account.address)].prefix(survivingAdds)), label)

                // The next launch finds an account its seed proves and adds
                // the signing key App Store 3.8.6 needs. No second restore.
                XCTAssertEqual(try restored.startup(), .ready, label)
                XCTAssertFalse(restored.settings.walletMigrationRecoveryRequired, label)
                XCTAssertEqual(try keyStatus(account, on: restored), .available, label)
                XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: restored.keychain), label)
                for tag in [KeystoreTag.seedTagForAddress(account.address),
                            KeystoreTag.secretKeyTagForAddress(account.address)] {
                    XCTAssertEqual(try restored.keychain.fetchKey(for: tag),
                                   try original.keychain.fetchKey(for: tag), label)
                }
                XCTAssertFalse(restored.keychain.changedExistingItems, label)
            }
        }
    }

    func testAKillDuringAnInPlaceKeyRestoreIsCompletedByTheNextLaunchWithThePhrase() throws {
        for survivingAdds in [1, 2] {
            let label = "dies after \(survivingAdds) Keychain write(s)"
            let original = try Installation()
            let first = try HistoricalWriter.phraseImport(phrase12, username: "First", order: 0, isSelected: true,
                                                          keystore: original.keychain.base)
            let secondPhrase = try phrase(entropy: 0x44, bytes: 16)
            let second = try HistoricalWriter.phraseImport(secondPhrase, username: "Second", order: 1,
                                                           isSelected: false, keystore: original.keychain.base)
            try KeySafetyStore.write([first, second], to: original.storeURL)
            XCTAssertEqual(try original.startup(), .ready, label)
            // A new iPhone: the files came back, the keys did not.
            let restored = try Installation()
            try FileManager.default.removeItem(at: restored.directory)
            try FileManager.default.copyItem(at: original.directory, to: restored.directory)
            XCTAssertEqual(try restored.startup(), .ready, label)
            let selection = try restored.selectedWalletSettings(accounts: [first, second])

            // Add account > import the second account's phrase; the process
            // dies between two Keychain writes.
            let dying = DyingKeychain(base: restored.keychain, survivingAdds: survivingAdds)
            let factory = AccountOperationFactory(keystore: dying, recoveryGate: restored.isolatedGate())
            let operation = factory.prepareAccountOperation(
                request: AccountCreationRequest(username: "Imported", type: .sora, derivationPath: "",
                                                cryptoType: .sr25519),
                mnemonic: try IRMnemonicCreator(language: .english).mnemonic(fromList: secondPhrase))
            operation.start()
            let prepared = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            XCTAssertThrowsError(try restored.insert(prepared, into: selection, factory: factory), label)
            XCTAssertTrue(dying.isDead, label)
            // The phrase is written first and the signing key last.
            XCTAssertEqual(restored.keychain.added, Array([KeystoreTag.entropyTagForAddress(second.address),
                KeystoreTag.seedTagForAddress(second.address)].prefix(survivingAdds)), label)
            XCTAssertTrue(restored.keychain.deleted.isEmpty, label)
            XCTAssertFalse(restored.settings.walletMigrationRecoveryRequired, label)

            // The next launch completes the account: phrase, seed and key,
            // byte for byte what App Store 3.8.6 had written.
            XCTAssertEqual(try restored.startup(), .ready, label)
            for tag in [KeystoreTag.entropyTagForAddress(second.address),
                        KeystoreTag.seedTagForAddress(second.address),
                        KeystoreTag.secretKeyTagForAddress(second.address)] {
                XCTAssertEqual(try restored.keychain.fetchKey(for: tag), try original.keychain.fetchKey(for: tag),
                               "\(label): \(tag.suffix(10))")
            }
            XCTAssertEqual(try keyStatus(second, on: restored), .available, label)
            XCTAssertTrue(try AppStore386Launch.canSign(second, keystore: restored.keychain), label)
            XCTAssertFalse(restored.keychain.changedExistingItems, label)
        }
    }

    func testOnTheRealKeychainAnInterruptedAccountWriteIsCompletedAddOnly() throws {
        let real = Keychain()
        let entropy = Data((0 ..< 16).map { _ in UInt8.random(in: 0 ... 255) })
        let phrase = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy).toString()
        let gate = WalletRecoveryCapabilityGate(settings: InMemorySettingsManager(),
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        func prepare() throws -> PreparedAccount {
            let operation = AccountOperationFactory(keystore: real, recoveryGate: gate).prepareAccountOperation(
                request: AccountCreationRequest(username: "Real Keychain", type: .sora, derivationPath: "",
                                                cryptoType: .sr25519),
                mnemonic: try IRMnemonicCreator(language: .english).mnemonic(fromList: phrase))
            operation.start()
            return try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }
        let account = try prepare().account
        let entropyTag = KeystoreTag.entropyTagForAddress(account.address)
        let seedTag = KeystoreTag.seedTagForAddress(account.address)
        let secretTag = KeystoreTag.secretKeyTagForAddress(account.address)
        // Only the items this test creates, for an address it generated.
        addTeardownBlock {
            for tag in [entropyTag, seedTag, secretTag] { try? real.deleteKey(for: tag) }
        }
        for tag in [entropyTag, seedTag, secretTag] { XCTAssertFalse(try real.checkKey(for: tag)) }

        // The process dies after the first of the three writes.
        XCTAssertThrowsError(try prepare().persist(to: DyingKeychain(base: real, survivingAdds: 1)))
        XCTAssertEqual(try real.fetchKey(for: entropyTag), entropy)
        XCTAssertFalse(try real.checkKey(for: seedTag))
        XCTAssertFalse(try real.checkKey(for: secretTag))

        // What the next start's backfill does for an account that has its
        // phrase and no signing key: add the seed, then the key.
        XCTAssertEqual(try WalletScopedKeyCompletion.addMissingCopies(for: account, keystore: real, recoveryGate: gate),
                       .added([seedTag, secretTag]))
        XCTAssertEqual(try real.fetchKey(for: entropyTag), entropy)
        XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: real))
        let stored = try [entropyTag, seedTag, secretTag].map { try real.fetchKey(for: $0) }

        // Importing the same phrase again adopts the three items as they are.
        try prepare().persist(to: real)
        XCTAssertEqual(try [entropyTag, seedTag, secretTag].map { try real.fetchKey(for: $0) }, stored)
    }

    func testSetUpAgainKilledAtAnyPointContinuesInTheSameFolder() throws {
        struct ProcessDied: Error {}
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("1234".utf8), with: KeystoreTag.pincode.rawValue)
        try KeySafetyStore.write([account], to: device.storeURL)
        device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        XCTAssertEqual(try device.startup(), .ready)
        // Readable transaction records stay where they are.
        _ = try Sora2PendingSubmissionStore(baseURL: device.directory)
            .stage(account: account.address, hash: transactionHash(0xa1))
        device.settings.setWalletMigrationRecovery(reason: "Some other integrity check")
        let marker = WalletMigrationRecoveryMarker.capture(device.settings)
        let keys = try device.keychain.bytes()
        let storeBytes = try Data(contentsOf: device.storeURL)
        func paths(_ device: Installation) -> WalletLocalStateSetAside.Paths {
            WalletLocalStateSetAside.Paths(storeURL: device.storeURL, applicationSupportURL: device.directory,
                setAsideRootURL: device.directory.appendingPathComponent("WalletSetAside"))
        }
        func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
        let root = paths(device).setAsideRootURL

        // 1. The process dies after the last move, before the wallet
        // settings are removed and the recovery marker is cleared. On the
        // way, the state at the start of the third move is kept for part 2.
        var killedBetweenMoves: KilledInstallation?
        var moves = 0
        XCTAssertThrowsError(try WalletLocalStateSetAside.setAside(settings: device.settings, expectedMarker: marker,
            paths: paths(device), lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.isolatedGate()),
            beforeMove: { _ in
                moves += 1
                if moves == 3 { killedBetweenMoves = try InterruptedWrite.capture(device, label: "between moves") }
            }, afterMoves: { throw ProcessDied() })) { XCTAssertTrue($0 is ProcessDied) }
        XCTAssertGreaterThanOrEqual(moves, 4)
        let folders = try InterruptedWrite.names(in: root)
        XCTAssertEqual(folders.count, 1)
        let folder = root.appendingPathComponent(folders[0])
        XCTAssertTrue(exists(folder.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName)))
        XCTAssertFalse(exists(device.storeURL))
        XCTAssertTrue(device.settings.hasRetainedWalletSettings())
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(device.settings), marker)
        // The next launch shows the recovery screen again; the user chooses
        // the action again, and it continues in that folder.
        let completed = try WalletLocalStateSetAside.setAside(settings: device.settings, expectedMarker: marker,
            paths: paths(device), lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.isolatedGate()))
        XCTAssertEqual(completed.lastPathComponent, folder.lastPathComponent)
        XCTAssertEqual(try InterruptedWrite.names(in: root), folders)
        XCTAssertFalse(exists(folder.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName)))
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("CoreData/UserDataModel.sqlite")), storeBytes)
        XCTAssertFalse(device.settings.hasRetainedWalletSettings())
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertTrue(exists(device.directory.appendingPathComponent("SORA/PendingTransactions/sora2-signed-v1.json")))
        XCTAssertFalse(exists(folder.appendingPathComponent("PendingTransactions")))
        XCTAssertEqual(try device.keychain.bytes(), keys)
        XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])

        // 2. The process dies between two moves.
        let revived = try XCTUnwrap(killedBetweenMoves).revive()
        scratch.append(try XCTUnwrap(killedBetweenMoves).directory)
        let revivedRoot = paths(revived).setAsideRootURL
        let started = try InterruptedWrite.names(in: revivedRoot)
        XCTAssertEqual(started.count, 1)
        let startedFolder = revivedRoot.appendingPathComponent(started[0])
        XCTAssertTrue(exists(startedFolder.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName)))
        XCTAssertTrue(exists(startedFolder.appendingPathComponent("CoreData/UserDataModel.sqlite")))
        XCTAssertTrue(exists(revived.directory.appendingPathComponent("SORA/WalletNetworks")))
        // Meanwhile the transaction records became unreadable: this time
        // they are set aside with the rest.
        try Data("a later version's journal".utf8).write(to: revived.directory
            .appendingPathComponent("SORA/PendingTransactions/sora2-signed-v2.json"))
        let revivedMarker = WalletMigrationRecoveryMarker.capture(revived.settings)
        XCTAssertTrue(revivedMarker.required)
        let continued = try WalletLocalStateSetAside.setAside(settings: revived.settings,
            expectedMarker: revivedMarker, paths: paths(revived),
            lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: revived.isolatedGate()))
        // One folder holds everything, each file once.
        XCTAssertEqual(try InterruptedWrite.names(in: revivedRoot), started)
        XCTAssertEqual(continued.lastPathComponent, started[0])
        XCTAssertFalse(exists(continued.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName)))
        XCTAssertEqual(try Data(contentsOf: continued.appendingPathComponent("CoreData/UserDataModel.sqlite")),
                       storeBytes)
        for name in ["CoreData/WalletMigrationSafety", "WalletNetworks", "WalletAccountCommits",
                     "PendingTransactions/sora2-signed-v1.json", "PendingTransactions/sora2-signed-v2.json"] {
            XCTAssertTrue(exists(continued.appendingPathComponent(name)), name)
        }
        XCTAssertFalse(try InterruptedWrite.names(in: continued).contains { $0.contains(".") && $0.hasPrefix("Wallet") },
                       "no file was set aside twice under a second name")
        XCTAssertFalse(exists(revived.storeURL))
        XCTAssertFalse(exists(revived.directory.appendingPathComponent("SORA/WalletNetworks")))
        XCTAssertFalse(revived.settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(try revived.keychain.bytes(), keys)
        XCTAssertEqual(try revived.startup(), .ready)
        XCTAssertEqual(try revived.rootDecision(selected: nil), [.welcomeBack])
    }
}
