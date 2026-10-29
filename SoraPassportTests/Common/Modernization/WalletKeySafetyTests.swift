// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

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

private func saveOwnerBindingFixture(_ pin: String, accounts: [AccountItem], keystore: KeystoreProtocol) throws {
    for account in accounts {
        try keystore.saveKey(JSONEncoder().encode(WalletOwnerPIN.Binding(pin: pin)),
                             with: account.address + WalletOwnerPIN.bindingSuffix)
    }
}


/// A Keychain that behaves like the real one for `addKey` (duplicates are
/// rejected) and records every write the code under test makes. Fixtures are
/// written through `base`, so they are not recorded.
private final class AddOnlyRecordingKeychain: KeystoreProtocol {
    let base = InMemoryKeychain()
    private(set) var added: [String] = []
    private(set) var updated: [String] = []
    private(set) var deleted: [String] = []
    var beforeListing: (() -> Void)?

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
    func allKeyIdentifiers() throws -> [String] {
        beforeListing?()
        return try base.allKeyIdentifiers()
    }

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
            let signature = try HistoricalCompatibilitySigner(account: account, secret: secret).sign(payload)
            try Sora2SignatureVerifier.verify(signature: signature,
                                              originalData: payload, secretKey: secret, account: account)
            return true
        }
    }
}

private final class HistoricalCompatibilitySigner: SigningWrapperProtocol {
    let account: AccountItem
    let secret: Data
    init(account: AccountItem, secret: Data) { self.account = account; self.secret = secret }
    func sign(_ data: Data) throws -> IRSignatureProtocol {
        switch account.cryptoType {
        case .sr25519: return try signSr25519(data, secretKeyData: secret, publicKeyData: account.publicKeyData)
        case .ed25519: return try signEd25519(data, secretKey: secret)
        case .ecdsa: return try signEcdsa(data, secretKey: secret)
        }
    }
}

private final class AuxiliaryReadFailureKeychain: KeystoreProtocol {
    let base: KeystoreProtocol
    let blockedSuffixes: [String]
    init(_ base: KeystoreProtocol, blockedSuffixes: [String] = ["-entropy", "-seed", "-deriv"]) {
        self.base = base; self.blockedSuffixes = blockedSuffixes
    }
    private func check(_ tag: String) throws {
        if blockedSuffixes.contains(where: { tag.hasSuffix($0) }) {
            throw KeystoreError.unexpectedFail
        }
    }
    func fetchKey(for identifier: String) throws -> Data { try check(identifier); return try base.fetchKey(for: identifier) }
    func checkKey(for identifier: String) throws -> Bool { try check(identifier); return try base.checkKey(for: identifier) }
    func allKeyIdentifiers() throws -> [String] { try base.allKeyIdentifiers() }
    func addKey(_ key: Data, with identifier: String) throws { throw KeystoreError.unexpectedFail }
    func updateKey(_ key: Data, with identifier: String) throws { throw KeystoreError.unexpectedFail }
    func deleteKey(for identifier: String) throws { throw KeystoreError.unexpectedFail }
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

/// The app's Core Data stack over one installation's database file,
/// configured as `UserDataStorageFacade` configures the app's own.
private final class OnDiskUserDataFacade: SoraPassport.StorageFacadeProtocol {
    let databaseService: CoreDataServiceProtocol

    init(storeURL: URL) throws {
        let modelName = UserStorageParams.modelVersion.rawValue
        let modelURL = Bundle.main.url(forResource: modelName, withExtension: "omo",
                                       subdirectory: UserStorageParams.modelDirectory)
            ?? Bundle.main.url(forResource: modelName, withExtension: "mom",
                               subdirectory: UserStorageParams.modelDirectory)
        let settings = CoreDataPersistentSettings(databaseDirectory: storeURL.deletingLastPathComponent(),
            databaseName: storeURL.lastPathComponent,
            incompatibleModelStrategy: UserStorageParams.incompatibleModelStrategy)
        databaseService = CoreDataService(configuration: CoreDataServiceConfiguration(
            modelURL: try XCTUnwrap(modelURL), storageType: .persistent(settings: settings)))
    }

    func createRepository<T, U>(filter: NSPredicate?, sortDescriptors: [NSSortDescriptor],
                                mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
    where T: Identifiable, U: NSManagedObject {
        CoreDataRepository(databaseService: databaseService, mapper: mapper, filter: filter,
                           sortDescriptors: sortDescriptors)
    }

    /// Saves (inserts or updates by address) account rows, as the app's
    /// repository saves do.
    func save(_ accounts: [AccountItem]) throws {
        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            createRepository(mapper: AnyCoreDataMapper(AccountItemMapper()))
        let operation = repository.saveOperation({ accounts }, { [] })
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }

    /// Before another stack (a startup, another version) opens the file.
    func close() throws { try databaseService.close() }
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

    /// The startup of `SplashInteractor`, against this installation: the
    /// production storage checks themselves (`WalletStorageStartup.runChecks`:
    /// helper-file sweep, journal and startup recovery, database migration,
    /// transaction records), then the production network bootstrap and the
    /// scoped-copy backfill.
    ///
    /// - Parameter sweepsHelperFilesFirst: the explicit sweep the storage
    ///   checks begin with. Tests pass false to show that each folder check
    ///   also copes by itself.
    @discardableResult
    func startup(checkpoint: ((UserStorageMigrationCheckpoint) throws -> Void)? = nil,
                 sweepsHelperFilesFirst: Bool = true) throws
        -> WalletStorageStartupOutcome {
        let gate = self.gate()
        let coordinator = WalletLifecycleCoordinator(recoveryGate: gate)
        let checks = WalletStorageStartup.runChecks(settings: settings, keystore: keychain, storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory, applicationSupportURL: directory,
            lifecycleCoordinator: coordinator, recoveryGate: gate,
            databaseMigrator: try migrator(gate: gate, checkpoint: checkpoint),
            sweepsHelperFiles: sweepsHelperFilesFirst, retryDelay: { _ in })
        // `SplashInteractor.performStorageMigration` routes from here: only a
        // ready wallet that is not waiting for its 1.x upgrade goes on to
        // `bootstrapWalletNetworks`.
        guard checks.outcome == .ready, !checks.deferredForLegacyUpgrade,
              !settings.walletMigrationRecoveryRequired else { return checks.outcome }
        let accounts = try KeySafetyStore.rows(at: storeURL)
        let selected = try SelectedWalletSettings.resolveSelection(accounts: accounts,
            legacySelectedAddress: settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue)?.identifier)
        let store = try WalletNetworkStore(baseURL: directory, recoveryGate: gate)
        try SplashInteractor.initializeWalletNetworksIfNeeded(accounts: accounts, selectedAddress: selected?.address,
            store: store, keystore: keychain, settings: settings, lifecycleCoordinator: coordinator,
            recoveryGate: gate)
        SplashInteractor.addScopedCopiesIfNeeded(accounts: accounts, store: store, keystore: keychain,
            lifecycleCoordinator: coordinator, recoveryGate: gate)
        return checks.outcome
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
            legacyUpgradeInteractorFactory: { _, _, _, _ in legacyImporter },
            initialPINAccounts: {
                if FileManager.default.fileExists(atPath: self.storeURL.path) {
                    return try KeySafetyStore.rows(at: self.storeURL)
                }
                return selected.map { [$0] } ?? []
            })
    }

    func rootDecision(selected: AccountItem?) throws -> [KeySafetyRootPresenterSpy.Decision] {
        let root = try rootInteractor(selected: selected)
        let spy = KeySafetyRootPresenterSpy()
        root.presenter = spy
        root.decideModuleSynchroniously()
        return spy.decisions
    }

    /// `SelectedWalletSettings` over an in-memory Core Data stack whose
    /// network synchronizer writes this installation's snapshot. With
    /// `OnDiskUserDataFacade` it works on this installation's own database
    /// file, as the app does.
    func selectedWalletSettings(accounts: [AccountItem] = [],
                                facade: SoraPassport.StorageFacadeProtocol = UserDataStorageTestFacade()) throws
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
            // As `SelectedWalletSettings.shared` does (the recovery marker of
            // a failure is set by `performUpdate` itself).
            walletNetworkMetadataSynchronizer: { accounts, walletId, displayName, lease in
                try coordinator.withExclusiveAccess(using: lease) {
                    try store.updateWalletDisplayName(walletId: walletId, displayName: displayName,
                                                      expectedAccounts: accounts)
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

    private func historicalVectors(_ name: String) throws -> [[String: Any]] {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json",
                                                         subdirectory: "HistoricalCrypto"))
        let file = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try XCTUnwrap(file["vectors"] as? [[String: Any]])
    }

    private func historicalAccount(_ vector: [String: Any]) throws -> AccountItem {
        let crypto = CryptoType(type: try XCTUnwrap(vector["cryptoType"] as? String).uppercased())
        return AccountItem(address: try XCTUnwrap(vector["address"] as? String), cryptoType: crypto,
            networkType: Chain.sora.addressType(), username: try XCTUnwrap(vector["id"] as? String),
            publicKeyData: try Data(hex: XCTUnwrap(vector["publicKeyHex"] as? String)),
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
    }

    func testOriginal386DependencyVectorsSurviveEveryDatabaseMigrationBoundary() throws {
        let fixtureNames = ["ios-386-vectors"] +
            (try FileManager.default.contentsOfDirectory(at: XCTUnwrap(Bundle(for: Self.self)
                .url(forResource: "HistoricalCrypto", withExtension: nil)), includingPropertiesForKeys: nil))
                .filter { $0.lastPathComponent.hasPrefix("ios-fearless-") || $0.lastPathComponent.hasPrefix("ios-ssfutils-") }
                .map { $0.deletingPathExtension().lastPathComponent }.sorted()
        XCTAssertEqual(fixtureNames.count, 6)
        let vectors = try fixtureNames.flatMap(historicalVectors)
        XCTAssertEqual(vectors.count, 120)
        for vector in vectors {
            let device = try Installation()
            let account = try historicalAccount(vector)
            let secret = try Data(hex: XCTUnwrap(vector["secretKeyHex"] as? String))
            let challenge = try Data(hex: XCTUnwrap(vector["challengeHex"] as? String))
            let signatureBytes = try Data(hex: XCTUnwrap(vector["signatureHex"] as? String))
            let historicalSignature: IRSignatureProtocol
            switch account.cryptoType {
            case .sr25519: historicalSignature = try SNSignature(rawData: signatureBytes)
            case .ed25519: historicalSignature = try EDSignature(rawData: signatureBytes)
            case .ecdsa: historicalSignature = try SECSignature(rawData: signatureBytes)
            }
            try device.keychain.base.saveSecretKey(secret, address: account.address)
            try device.keychain.base.saveEntropy(Data(hex: XCTUnwrap(vector["entropyHex"] as? String)),
                                                 address: account.address)
            try device.keychain.base.saveSeed(Data(hex: XCTUnwrap(vector["seedHex"] as? String)),
                                              address: account.address)
            let path = try XCTUnwrap(vector["derivationPath"] as? String)
            if !path.isEmpty { try device.keychain.base.saveDeriviation(path, address: account.address) }
            let originals = try device.keychain.bytes()
            // Independently produced signature from the historical dependency,
            // checked by today's production verifier without deriving a new key.
            try Sora2SignatureVerifier.verify(signature: historicalSignature, originalData: challenge,
                                              secretKey: secret, account: account)
            try KeySafetyStore.write([account], to: device.storeURL, version: .version1)
            device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
            var interruptions: [(UserStorageMigrationCheckpoint, Installation)] = []
            XCTAssertEqual(try device.startup(checkpoint: { checkpoint in
                interruptions.append((checkpoint, try device.copy()))
            }), .ready, account.username)
            XCTAssertEqual(Set(interruptions.map { $0.0 }), Set(UserStorageMigrationCheckpoint.allCases), account.username)
            for (boundary, restart) in interruptions {
                XCTAssertEqual(try restart.startup(), .ready, "\(account.username): \(boundary)")
                XCTAssertEqual(try restart.keychain.bytes(), originals, account.username)
                XCTAssertEqual(try KeySafetyStore.rows(at: restart.storeURL).map(\.address), [account.address])
                XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: restart.keychain), account.username)
            }
            // Read an encrypted JSON written by the actual old builder.
            let oldJSON = try JSONSerialization.data(withJSONObject: XCTUnwrap(vector["exportedJSON"]))
            let password = try XCTUnwrap(vector["jsonPassword"] as? String)
            let oldExport = try KeystoreExtractor().extractFromDefinition(
                JSONDecoder().decode(KeystoreDefinition.self, from: oldJSON), password: password)
            XCTAssertEqual(oldExport.address, account.address)
            try LegacySoraIdentityValidator.validateSigningSecret(address: account.address,
                publicKey: account.publicKeyData, cryptoType: account.cryptoType, networkType: account.networkType,
                secret: oldExport.secretKeyData, recoveryGate: device.isolatedGate())
            // Today's backup must also restore the same historical identity.
            let currentJSON = try KeystoreExportWrapper(keystore: device.keychain).export(account: account, password: password)
            let currentExport = try KeystoreExtractor().extractFromDefinition(
                JSONDecoder().decode(KeystoreDefinition.self, from: currentJSON), password: password)
            XCTAssertEqual(currentExport.address, account.address)
            XCTAssertEqual(currentExport.publicKeyData, account.publicKeyData)
            try LegacySoraIdentityValidator.validateSigningSecret(address: account.address,
                publicKey: account.publicKeyData, cryptoType: account.cryptoType, networkType: account.networkType,
                secret: currentExport.secretKeyData, recoveryGate: device.isolatedGate())
            XCTAssertEqual(try device.keychain.bytes(), originals, account.username)
        }
    }

    func testOriginalOneXDependenciesRetainIrohaIdentityThroughScopedSora2Activation() throws {
        let vectors = try historicalVectors("ios-1x-vectors")
        XCTAssertEqual(vectors.count, 2)
        let converted = try XCTUnwrap(historicalVectors("ios-386-vectors").first {
            ($0["id"] as? String) == "ios-386-sr25519-15words-19"
        })
        let sora2 = try historicalAccount(converted)
        for vector in vectors {
            let phrase = try XCTUnwrap(vector["phrase"] as? String)
            let password = try XCTUnwrap(vector["password"] as? String)
            let oldSecret = try Data(hex: XCTUnwrap(vector["secretKeyHex"] as? String))
            let oldPublic = try Data(hex: XCTUnwrap(vector["publicKeyHex"] as? String))
            let challenge = try Data(hex: XCTUnwrap(vector["challengeHex"] as? String))
            let pair = try IRKeypairFacade().deriveKeypair(from: phrase, password: password)
            XCTAssertEqual(pair.privateKey().rawData(), oldSecret)
            XCTAssertEqual(pair.publicKey().rawData(), oldPublic)
            let signature = try IRIrohaSigner(privateKey: IRIrohaPrivateKey(rawData: oldSecret)).sign(challenge)
            XCTAssertEqual(signature.rawData(), try Data(hex: XCTUnwrap(vector["signatureHex"] as? String)))
            // The 1.x app did not persist a mnemonic password. The extra
            // password vector verifies the old dependency's KDF/signature;
            // automatic entropy-only activation is defined only for the
            // empty password actually used by the historical app writer.
            guard password.isEmpty else { continue }
            let device = try Installation()
            try device.keychain.base.addKey(oldSecret, with: "privateKey")
            try device.keychain.base.addKey(Data(hex: XCTUnwrap(vector["entropyHex"] as? String)), with: "seedEntropy")
            let originals = try device.keychain.bytes()
            // This is the committed SORA2 row at the interrupted transition;
            // its expected identity comes from the original 3.8.6 dependency.
            try KeySafetyStore.write([sora2], to: device.storeURL)
            device.settings.set(value: sora2, for: SettingsKey.selectedAccount.rawValue)
            XCTAssertEqual(try device.startup(), .ready)
            for (tag, bytes) in originals { XCTAssertEqual(try device.keychain.fetchKey(for: tag), bytes) }
            XCTAssertEqual(try device.keychain.fetchSecretKeyForAddress(sora2.address),
                try Data(hex: XCTUnwrap(converted["secretKeyHex"] as? String)))
            XCTAssertTrue(try AppStore386Launch.canSign(sora2, keystore: device.keychain))
            var backup = try WalletBackupMaterial.load(for: sora2, keystore: device.keychain,
                                                       recoveryGate: device.isolatedGate())
            defer { backup.wipe() }
            XCTAssertEqual(backup.entropy, try Data(hex: XCTUnwrap(vector["entropyHex"] as? String)))
            XCTAssertEqual(try device.startup(), .ready)
            for (tag, bytes) in originals { XCTAssertEqual(try device.keychain.fetchKey(for: tag), bytes) }
        }
    }

    func testMigrationManifestHashesPasswordPathsAndReadsEarlierPlaintextManifests() throws {
        for historicalManifest in [false, true] {
            let device = try Installation()
            let path = "//audit/soft///public-fixture-password"
            let account = try HistoricalWriter.phraseImport(phrase12, path: path, keystore: device.keychain.base)
            try KeySafetyStore.write([account], to: device.storeURL)
            let keys = try device.keychain.bytes()
            let safety = device.directory.appendingPathComponent("WalletMigrationSafety")
            func manifestURL() throws -> URL {
                let attempts = try FileManager.default.contentsOfDirectory(at: safety,
                    includingPropertiesForKeys: nil)
                return try XCTUnwrap(attempts.first).appendingPathComponent("account-manifest.json")
            }
            XCTAssertEqual(try device.startup(checkpoint: { checkpoint in
                if checkpoint == .preparationCreated {
                    XCTAssertEqual(try safety.resourceValues(forKeys: [.isExcludedFromBackupKey])
                        .isExcludedFromBackup, true)
                }
                if historicalManifest, checkpoint == .inventoryWritten {
                    // Earlier candidates wrote this field in plaintext. Preserve
                    // that artifact and verify its compatibility on the next run.
                    let url = try manifestURL()
                    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
                    var accounts = try XCTUnwrap(json["accounts"] as? [[String: Any]])
                    accounts[0].removeValue(forKey: "derivationPathSHA256")
                    accounts[0]["derivationPath"] = path
                    json["accounts"] = accounts
                    try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]).write(to: url)
                }
            }), .ready)
            let url = try manifestURL()
            let bytes = try Data(contentsOf: url)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            let saved = try XCTUnwrap((json["accounts"] as? [[String: Any]])?.first)
            if historicalManifest {
                XCTAssertEqual(saved["derivationPath"] as? String, path)
            } else {
                XCTAssertNil(saved["derivationPath"])
                XCTAssertEqual(saved["derivationPathSHA256"] as? String,
                    Data(SHA256.hash(data: Data(path.utf8))).toHex())
                XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("public-fixture-password"))
            }
            // Existing copies from an older candidate also receive backup
            // exclusion before their normal verification/resume path.
            var oldSafety = safety
            var oldAttributes = URLResourceValues()
            oldAttributes.isExcludedFromBackup = false
            try oldSafety.setResourceValues(oldAttributes)
            XCTAssertEqual(try device.startup(), .ready)
            XCTAssertEqual(try safety.resourceValues(forKeys: [.isExcludedFromBackupKey])
                .isExcludedFromBackup, true)
            XCTAssertEqual(try Data(contentsOf: url), bytes)
            XCTAssertEqual(try device.keychain.bytes(), keys)
            XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain))
        }
    }

    func testWorkingHistoricalSecretsSurviveStaleBackupsAndJSONRoundTrip() throws {
        let cases: [(CryptoType, String)] = [(.sr25519, "/soft"), (.sr25519, "//hard"),
            (.sr25519, "//hard///password"), (.ed25519, "//hard"), (.ecdsa, "//hard")]
        for (crypto, path) in cases {
            let device = try Installation()
            let account = try HistoricalWriter.phraseImport(phrase12, path: path,
                cryptoType: crypto, keystore: device.keychain.base)
            let originalSecret = try device.keychain.fetchKey(for: KeystoreTag.secretKeyTagForAddress(account.address))
            if crypto == .ed25519 {
                // 3.8.6 signs using the seed even if a JSON's redundant public half is damaged.
                try device.keychain.base.saveSecretKey(Data(originalSecret.prefix(32)) + Data(repeating: 0x42, count: 32),
                                                       address: account.address)
            }
            try device.keychain.base.saveSeed(Data(repeating: 0x73, count: 32), address: account.address)
            try device.keychain.base.saveEntropy(Data(repeating: 0x27, count: 16), address: account.address)
            try device.keychain.base.saveDeriviation("not a derivation path", address: account.address)
            let before = try device.keychain.bytes()
            let gate = device.isolatedGate()
            let retainedSecret = try XCTUnwrap(LegacySoraSecretResolver.resolve(account: account,
                keystore: device.keychain, recoveryGate: gate))
            let payload = Data("historical signing compatibility".utf8)
            let signature = try HistoricalCompatibilitySigner(account: account, secret: retainedSecret).sign(payload)
            XCTAssertNoThrow(try Sora2SignatureVerifier.verify(signature: signature, originalData: payload,
                secretKey: retainedSecret, account: account))
            var backup = try WalletBackupMaterial.load(for: account, keystore: device.keychain, recoveryGate: gate)
            XCTAssertNil(backup.entropy)
            XCTAssertNil(backup.seed)
            XCTAssertEqual(backup.derivationStatus, .mismatch)
            backup.wipe()
            let discovered = try XCTUnwrap(RetainedKeychainWalletDiscovery.prove(address: account.address,
                keystore: device.keychain, recoveryGate: gate))
            XCTAssertEqual(discovered.cryptoType, crypto)
            XCTAssertFalse(discovered.hasPhrase)
            let prepared = try RetainedKeychainWalletDiscovery.preparedAccount(for: discovered,
                username: account.username, keystore: device.keychain, recoveryGate: gate)
            try prepared.persist(to: device.keychain)
            try KeySafetyStore.write([account], to: device.storeURL)
            XCTAssertEqual(try device.startup(), .ready)
            let store = try device.networkStore()
            try WalletNetworkModelMigrator(keystore: device.keychain, store: store, settings: device.settings,
                lifecycleCoordinator: device.coordinator, recoveryGate: gate).migrate(
                    accounts: [account], selectedAddress: account.address)
            XCTAssertEqual(try store.load()?.wallets.first?.secretSource, .legacySecret)
            let json = try KeystoreExportWrapper(keystore: device.keychain).export(account: account, password: "fixture-password")
            let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: json)
            let exported = try KeystoreExtractor().extractFromDefinition(definition, password: "fixture-password")
            XCTAssertEqual(exported.address, account.address)
            XCTAssertEqual(exported.publicKeyData, account.publicKeyData)
            try WalletCloudBackupRecoveryService.validateSecretEncoding(exported.secretKeyData,
                cryptoType: crypto, publicKey: account.publicKeyData)
            try LegacySoraIdentityValidator.validateSigningSecret(address: account.address,
                publicKey: account.publicKeyData, cryptoType: crypto, networkType: account.networkType,
                secret: exported.secretKeyData, recoveryGate: gate)
            XCTAssertEqual(try device.keychain.bytes(), before)
            XCTAssertFalse(device.keychain.changedExistingItems)
        }
    }

    func testUnreadableAuxiliaryTagsCannotBlockAProvenDirectSecret() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        let keys = AuxiliaryReadFailureKeychain(device.keychain)
        let gate = device.isolatedGate()
        XCTAssertNotNil(try LegacySoraSecretResolver.resolve(account: account, keystore: keys, recoveryGate: gate))
        XCTAssertEqual(try WalletAccountKeyAvailability.status(for: account, keystore: keys,
            settings: device.settings, activeSnapshot: nil, recoveryGate: gate), .available)
        let discovered = try XCTUnwrap(RetainedKeychainWalletDiscovery.prove(address: account.address,
            keystore: keys, recoveryGate: gate))
        let prepared = try RetainedKeychainWalletDiscovery.preparedAccount(for: discovered,
            username: account.username, keystore: keys, recoveryGate: gate)
        XCTAssertNoThrow(try prepared.persist(to: keys))
        var backup = try WalletBackupMaterial.load(for: account, keystore: keys, recoveryGate: gate)
        XCTAssertEqual(backup.phraseStatus, .unreadable)
        XCTAssertEqual(backup.seedStatus, .unreadable)
        backup.wipe()
    }

    func testBackupSourcesAreVerifiedIndependentlyAfterHistoricalDoubleImport() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, path: "//1", cryptoType: .ecdsa,
                                                       keystore: device.keychain.base)
        let child = try device.keychain.fetchKey(for: KeystoreTag.secretKeyTagForAddress(account.address))
        let imported = try HistoricalWriter.seedImport(child, cryptoType: .ecdsa, keystore: device.keychain.base)
        XCTAssertEqual(imported.address, account.address)
        // The old writer leaves parent entropy/path next to the newly imported child seed.
        let before = try device.keychain.bytes()
        var backup = try WalletBackupMaterial.load(for: account, keystore: device.keychain, recoveryGate: device.isolatedGate())
        XCTAssertEqual(backup.phraseStatus, .matching)
        XCTAssertEqual(backup.seedStatus, .mismatch)
        backup.wipe()
        XCTAssertNotNil(try LegacySoraSecretResolver.resolve(account: account,
            keystore: device.keychain, recoveryGate: device.isolatedGate()))
        XCTAssertEqual(try device.keychain.bytes(), before)
    }

    func testMalformedDirectSecretsFailBeforeNativeCryptoAndDoNotUseFallbacks() throws {
        for crypto in [CryptoType.sr25519, .ed25519, .ecdsa] {
            let device = try Installation()
            let account = try HistoricalWriter.phraseImport(phrase12, cryptoType: crypto, keystore: device.keychain.base)
            for length in [0, 1, 31, 33, 63, 65] {
                try device.keychain.base.saveSecretKey(Data(repeating: 1, count: length), address: account.address)
                XCTAssertThrowsError(try LegacySoraSecretResolver.resolve(account: account,
                    keystore: device.keychain, recoveryGate: device.isolatedGate()))
            }
        }
    }

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

    func testDriveRecoveryUsesVerifiedJSONDespiteStaleOtherFormatsAndCryptoMetadata() throws {
        for crypto in [CryptoType.ed25519, .ecdsa] {
            let reference = try Installation()
            let account = try HistoricalWriter.phraseImport(phrase12, path: "//1", cryptoType: crypto,
                                                           keystore: reference.keychain.base)
            let password = "historical-drive-password"
            let json = try KeystoreExportWrapper(keystore: reference.keychain).export(account: account, password: password)
            var fields = try XCTUnwrap(JSONSerialization.jsonObject(with: appStore386Backup(
                address: account.address, phrase: try phrase(entropy: 7, bytes: 16),
                seed: Data(repeating: 9, count: 32), password: password)) as? [String: Any])
            fields["json"] = ["substrateJson": try XCTUnwrap(String(data: json, encoding: .utf8))]
            let device = try Installation()
            try KeySafetyStore.write([account], to: device.storeURL)
            device.settings.setWalletMigrationRecovery(reason: UserStorageMigrationError
                .privacySafeRecoveryDescription(for: UserStorageMigrationError.missingWalletSecret("x")))
            try WalletCloudBackupRecoveryService.restore(data: JSONSerialization.data(withJSONObject: fields),
                password: password, account: account, migrator: device.migrator(), baseURL: device.directory,
                lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.isolatedGate()))
            XCTAssertEqual(device.keychain.added, [KeystoreTag.secretKeyTagForAddress(account.address)])
            XCTAssertEqual(try device.startup(), .ready)
            XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain))
        }
    }

    func testDriveRepairFallsThroughStaleSourcesAndPreservesFailedCredentials() throws {
        for crypto in [CryptoType.sr25519, .ed25519, .ecdsa] {
            let reference = try Installation()
            let account = try HistoricalWriter.phraseImport(phrase12, path: "//1", cryptoType: crypto,
                                                           keystore: reference.keychain.base)
            let password = "public-repair-backup-password"
            let json = try KeystoreExportWrapper(keystore: reference.keychain).export(account: account, password: password)
            var fields = try XCTUnwrap(JSONSerialization.jsonObject(with: appStore386Backup(
                address: account.address, phrase: try phrase(entropy: 7, bytes: 16),
                seed: Data(repeating: 9, count: 32), password: password)) as? [String: Any])
            fields["json"] = ["substrateJson": try XCTUnwrap(String(data: json, encoding: .utf8))]
            let device = try Installation()
            try KeySafetyStore.write([account], to: device.storeURL)
            let broken = Data([0xff, 0x81])
            try device.keychain.base.addKey(broken, with: KeystoreTag.secretKeyTagForAddress(account.address))
            try device.keychain.base.addKey(Data("1234".utf8), with: KeystoreTag.pincode.rawValue)
            let service = WalletCredentialRepair(keystore: device.keychain, settings: device.settings,
                recoveryGate: device.isolatedGate(), lifecycleCoordinator: device.coordinator)
            let backup = try JSONSerialization.data(withJSONObject: fields)
            let before = try device.keychain.bytes()
            XCTAssertThrowsError(try WalletCloudBackupRecoveryService.prepareForRepair(data: backup,
                password: "incorrect", account: account, service: service))
            XCTAssertEqual(try device.keychain.bytes(), before)
            let candidate = try WalletCloudBackupRecoveryService.prepareForRepair(data: backup,
                password: password, account: account, service: service)
            XCTAssertEqual(try service.repair(prepared: candidate, currentAccounts: { [account] },
                pin: "1234", explicitlyConfirmed: true), .repaired)
            XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain))
            let preserved = try device.keychain.allKeyIdentifiers()
                .filter { $0.hasPrefix(WalletCredentialRepair.quarantinePrefix) }
                .map { try device.keychain.fetchKey(for: $0) }
            XCTAssertTrue(preserved.contains(broken))
            XCTAssertNil(try device.keychain.fetchEntropyForAddress(account.address), "Stale phrase is not adopted")
            XCTAssertNil(try device.keychain.fetchSeedForAddress(account.address), "Stale seed is not adopted")
        }
    }

    func testOnboardingBackupFallsThroughToTheFirstSourceThatProvesItsAddress() throws {
        let device = try Installation()
        let expected = try HistoricalWriter.phraseImport(phrase12, cryptoType: .ecdsa, keystore: device.keychain.base)
        let factory = AccountOperationFactory(keystore: InMemoryKeychain(), recoveryGate: device.isolatedGate())
        let wrongMnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: phrase(entropy: 8, bytes: 16))
        let wrong = factory.prepareAccountOperation(request: AccountCreationRequest(username: "Wrong", type: .sora,
            derivationPath: "", cryptoType: .sr25519), mnemonic: wrongMnemonic)
        let correctSeed = try device.keychain.fetchKey(for: KeystoreTag.seedTagForAddress(expected.address))
        let correct = factory.prepareAccountOperation(request: AccountImportSeedRequest(seed: correctSeed.toHex(),
            username: "Correct", networkType: .sora, derivationPath: "", cryptoType: .ecdsa))
        let operation = BaseAccountImportInteractor.firstMatchingAddress(expected.address, candidates: [wrong, correct])
        operation.start()
        let prepared = try XCTUnwrap(operation.result).get()
        XCTAssertEqual(prepared.account.address, expected.address)
        prepared.discard()
        XCTAssertEqual(try device.keychain.allKeyIdentifiers().count, 3)
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
                       .welcomeBack(adoptableWallets: 0, walletsWithPhrase: 0, retainedPinUsable: false))

        let selection = try device.selectedWalletSettings()
        let imported = try device.importPhrase(phrase12, into: selection)
        XCTAssertEqual(imported.address, account.address)
        let setupTag = WalletOwnerPIN.setupPrefix + account.address
        XCTAssertEqual(device.keychain.added, [setupTag])
        XCTAssertFalse(device.keychain.changedExistingItems)
        let after = try device.keychain.bytes()
        XCTAssertEqual(Set(after.keys), Set(retained.keys).union([setupTag]))
        for (tag, bytes) in retained { XCTAssertEqual(after[tag], bytes, tag) }
        XCTAssertTrue(try WalletOwnerPIN(keystore: device.keychain, settings: device.settings,
            recoveryGate: device.isolatedGate()).requiresInitialSetup(accounts: [imported]))
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
        try saveOwnerBindingFixture("246810", accounts: [phraseWallet, seedWallet, jsonWallet], keystore: device.keychain.base)
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
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("246810".utf8))
        XCTAssertNoThrow(try WalletRetainedPinGate.verify("246810", keystore: device.keychain, settings: device.settings))

        let result = RetainedKeychainWalletDiscovery.restore(inventory.adoptable, keystore: device.keychain,
            selectedWalletSettings: try device.selectedWalletSettings(),
            lifecycleCoordinator: device.coordinator,
            recoveryGate: device.isolatedGate())
        XCTAssertTrue(result.failedAddresses.isEmpty)
        let restored = result.restored
        XCTAssertEqual(Set(restored.map(\.address)), Set(inventory.adoptable.map(\.address)))
        XCTAssertTrue((device.keychain.added + device.keychain.updated + device.keychain.deleted)
            .allSatisfy { $0.hasSuffix(WalletOwnerPIN.throttleSuffix) })
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
                settings: device.settings, now: start, uptime: 1000, boot: "test-boot")) {
                if attempt < 3 {
                    XCTAssertEqual($0 as? WalletRetainedPinGate.Failure, .incorrectPin(attemptsBeforeWait: 3 - attempt))
                } else {
                    guard case .locked? = $0 as? WalletRetainedPinGate.Failure else { return XCTFail("\($0)") }
                }
            }
        }
        XCTAssertThrowsError(try WalletRetainedPinGate.verify("246810", keystore: device.keychain,
            settings: device.settings, now: start.addingTimeInterval(30), uptime: 1030, boot: "test-boot")) {
            guard case .locked? = $0 as? WalletRetainedPinGate.Failure else { return XCTFail("\($0)") }
        }
        XCTAssertTrue(WalletRecoveryStateProbe.welcomeBack(keystore: device.keychain, settings: device.settings)
            .options.canRestoreExistingKeys)
        XCTAssertNoThrow(try WalletRetainedPinGate.verify("246810", keystore: device.keychain,
            settings: device.settings, now: start.addingTimeInterval(61), uptime: 1061, boot: "test-boot"))
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("246810".utf8))
    }

    func testShowRecoveryPhraseAfterThePinOnlyForProvenPhrases() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        let seedAccount = try HistoricalWriter.seedImport(Data(repeating: 31, count: 32), cryptoType: .sr25519,
                                                          keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("135790".utf8), with: KeystoreTag.pincode.rawValue)
        try saveOwnerBindingFixture("135790", accounts: [account, seedAccount], keystore: device.keychain.base)
        XCTAssertEqual(WalletRecoveryPhraseReveal.availableAddresses(accounts: [account, seedAccount],
            keystore: device.keychain, recoveryGate: device.isolatedGate()), [account.address])
        XCTAssertThrowsError(try WalletRecoveryPhraseReveal.reveal(pin: "000000", accounts: [account],
            keystore: device.keychain, settings: device.settings, recoveryGate: device.isolatedGate()))
        let entries = try WalletRecoveryPhraseReveal.reveal(pin: "135790", accounts: [account, seedAccount],
            keystore: device.keychain, settings: device.settings, recoveryGate: device.isolatedGate())
        XCTAssertEqual(entries.map(\.address), [account.address])
        XCTAssertEqual(entries.first?.words.joined(separator: " "), phrase12)
        XCTAssertTrue((device.keychain.added + device.keychain.updated + device.keychain.deleted)
            .allSatisfy { $0.hasSuffix(WalletOwnerPIN.throttleSuffix) })
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
            paths: paths, lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: device.isolatedGate()),
            beforeMove: { _ in
                XCTAssertEqual(try paths.setAsideRootURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
                    .isExcludedFromBackup, true)
                let folder = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: paths.setAsideRootURL,
                    includingPropertiesForKeys: nil).first)
                XCTAssertEqual(try folder.resourceValues(forKeys: [.isExcludedFromBackupKey])
                    .isExcludedFromBackup, true)
                XCTAssertTrue(FileManager.default.fileExists(atPath:
                    folder.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName).path))
            })
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

    func testMissingDatabasePreservesStaleMetadataAndRoutesFromActualKeys() throws {
        for hasKeys in [false, true] {
            for staleMarker in [false, true] {
                let device = try Installation()
                let original = InMemoryKeychain()
                let account = try HistoricalWriter.phraseImport(phrase12, keystore: original)
                if hasKeys {
                    for tag in try original.allKeyIdentifiers() {
                        try device.keychain.base.addKey(original.fetchKey(for: tag), with: tag)
                    }
                }
                // A restored PIN/username alone must not claim a wallet exists.
                try device.keychain.base.addKey(Data("1234".utf8), with: KeystoreTag.pincode.rawValue)
                device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
                let network = device.directory.appendingPathComponent("SORA/WalletNetworks")
                try FileManager.default.createDirectory(at: network, withIntermediateDirectories: true)
                try Data("stale restored metadata".utf8).write(to: network.appendingPathComponent("active.json"))
                if staleMarker { device.settings.setWalletMigrationRecovery(reason: "earlier build") }
                let before = try device.keychain.bytes()
                let checks = WalletStorageStartup.runChecks(settings: device.settings, keystore: device.keychain,
                    storeURL: device.storeURL, modelDirectory: UserStorageParams.modelDirectory,
                    applicationSupportURL: device.directory, lifecycleCoordinator: device.coordinator,
                    recoveryGate: device.gate(), databaseMigrator: try device.migrator(), retryDelay: { _ in })
                XCTAssertEqual(checks.outcome, .ready)
                XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
                XCTAssertFalse(device.settings.hasRetainedWalletSettings())
                XCTAssertFalse(FileManager.default.fileExists(atPath: network.appendingPathComponent("active.json").path))
                XCTAssertEqual(try device.keychain.bytes(), before)
                XCTAssertEqual(try device.rootDecision(selected: nil), hasKeys ? [.welcomeBack] : [.onboarding])
                let root = device.directory.appendingPathComponent("WalletSetAside")
                let folder = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first)
                XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("WalletNetworks/active.json")),
                               Data("stale restored metadata".utf8))
                XCTAssertNotNil(try PropertyListSerialization.propertyList(from:
                    Data(contentsOf: folder.appendingPathComponent("wallet-settings.plist")), format: nil) as? [String: Any])
            }
        }
    }

    func testPreAccountModelStartupKeepsTheLegacyDisplayNameInPlace() throws {
        for retainsIrohaKey in [false, true] {
            for emptyNetworkDirectory in [false, true] {
                let device = try Installation()
                let historicalPhrase = try phrase(entropy: 0x11, bytes: 20)
                _ = try HistoricalWriter.version1(phrase: historicalPhrase, keystore: device.keychain.base)
                if !retainsIrohaKey { try device.keychain.base.deleteKey(for: "privateKey") }
                device.settings.set(value: "Public legacy fixture", for: KeystoreTag.legacyUsername.rawValue)
                if emptyNetworkDirectory {
                    try FileManager.default.createDirectory(at:
                        device.directory.appendingPathComponent("SORA/WalletNetworks"), withIntermediateDirectories: true)
                }
                let before = try device.keychain.bytes()
                let checks = WalletStorageStartup.runChecks(settings: device.settings, keystore: device.keychain,
                    storeURL: device.storeURL, modelDirectory: UserStorageParams.modelDirectory,
                    applicationSupportURL: device.directory, lifecycleCoordinator: device.coordinator,
                    recoveryGate: device.gate(), databaseMigrator: try device.migrator(), retryDelay: { _ in })
                XCTAssertEqual(checks.outcome, .ready)
                XCTAssertTrue(checks.deferredForLegacyUpgrade)
                XCTAssertEqual(try LegacyWalletUpgradeDisplayNameResolver.resolve(
                    settings: device.settings, keystore: device.keychain), "Public legacy fixture")
                XCTAssertEqual(try device.rootDecision(selected: nil), [.legacyWalletUpgrade])
                XCTAssertEqual(try device.keychain.bytes(), before)
                XCTAssertFalse(FileManager.default.fileExists(atPath: device.storeURL.path))
                XCTAssertFalse(FileManager.default.fileExists(atPath:
                    device.directory.appendingPathComponent("WalletSetAside").path))
            }
        }
    }

    func testMissingDatabaseClassificationRechecksAfterConcurrentWalletCommit() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        let observedMissing = DispatchSemaphore(value: 0)
        let continueRead = DispatchSemaphore(value: 0)
        let done = expectation(description: "metadata classification finished")
        device.keychain.beforeListing = {
            observedMissing.signal()
            XCTAssertEqual(continueRead.wait(timeout: .now() + 10), .success)
        }
        let lease = device.coordinator.acquire()
        defer { lease.release() }
        DispatchQueue.global().async {
            defer { done.fulfill() }
            do {
                let result = try WalletMissingDatabaseRecovery.preserveStaleMetadata(
                    settings: device.settings, keystore: device.keychain,
                    paths: .init(storeURL: device.storeURL, applicationSupportURL: device.directory,
                                 setAsideRootURL: device.directory.appendingPathComponent("WalletSetAside")),
                    lifecycleCoordinator: device.coordinator)
                XCTAssertNil(result)
            } catch { XCTFail("Unexpected classification failure: \(error)") }
        }
        XCTAssertEqual(observedMissing.wait(timeout: .now() + 10), .success)
        try KeySafetyStore.write([account], to: device.storeURL)
        let committedBytes = try Data(contentsOf: device.storeURL)
        continueRead.signal()
        lease.release()
        wait(for: [done], timeout: 15)
        device.keychain.beforeListing = nil
        XCTAssertEqual(try Data(contentsOf: device.storeURL), committedBytes)
        XCTAssertTrue(device.settings.hasRetainedWalletSettings())
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            device.directory.appendingPathComponent("WalletSetAside").path))
    }

    func testAutomaticStaleMetadataPreservationKeepsUnreadablePendingTransfersLive() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        let pending = device.directory.appendingPathComponent("SORA/PendingTransactions")
        try FileManager.default.createDirectory(at: pending.deletingLastPathComponent(), withIntermediateDirectories: true)
        let evidence = Data("unreadable pending transfer evidence".utf8)
        try evidence.write(to: pending)
        let result = try WalletMissingDatabaseRecovery.preserveStaleMetadata(settings: device.settings,
            keystore: device.keychain, paths: .init(storeURL: device.storeURL, applicationSupportURL: device.directory,
            setAsideRootURL: device.directory.appendingPathComponent("WalletSetAside")), lifecycleCoordinator: device.coordinator)
        XCTAssertNil(result)
        XCTAssertEqual(try Data(contentsOf: pending), evidence)
        XCTAssertTrue(device.settings.hasRetainedWalletSettings())
        XCTAssertFalse(FileManager.default.fileExists(atPath: device.directory.appendingPathComponent("WalletSetAside").path))
    }

    func testPreservedReturnCannotChangePINWhileCredentialRepairIsPending() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("1234".utf8), with: KeystoreTag.pincode.rawValue)
        try saveOwnerBindingFixture("1234", accounts: [account], keystore: device.keychain.base)
        let owner = WalletOwnerPIN(keystore: device.keychain, settings: device.settings)
        let grant = try owner.authorizeRetained("1234", addresses: [account.address])
        // Existence alone blocks PIN publication, including an unreadable intent.
        try device.keychain.base.addKey(Data("pending evidence".utf8), with: WalletCredentialRepair.pendingTag)
        let before = try device.keychain.bytes()
        XCTAssertThrowsError(try owner.setPINForPreservedRestore("5678", accounts: [account],
                                                               authorizations: [grant]))
        XCTAssertEqual(try device.keychain.bytes(), before)
    }

    func testPreservedGenerationReturnSurvivesEveryMoveWithoutChangingWalletKeys() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("1234".utf8), with: KeystoreTag.pincode.rawValue)
        try saveOwnerBindingFixture("1234", accounts: [account], keystore: device.keychain.base)
        try KeySafetyStore.write([account], to: device.storeURL)
        device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        XCTAssertEqual(try device.startup(), .ready)
        let before = try device.keychain.bytes()
        func paths(_ device: Installation) -> WalletLocalStateSetAside.Paths {
            .init(storeURL: device.storeURL, applicationSupportURL: device.directory,
                  setAsideRootURL: device.directory.appendingPathComponent("WalletSetAside"))
        }
        let folder = try WalletLocalStateSetAside.setAside(settings: device.settings, expectedMarker: nil,
            paths: paths(device), lifecycleCoordinator: device.coordinator)
        XCTAssertEqual(WalletPreservedGeneration.available(paths: paths(device), settings: device.settings), [folder])
        XCTAssertThrowsError(try WalletPreservedGeneration.restore(folder: folder, paths: paths(device),
            settings: device.settings, keystore: device.keychain, grants: [], newPIN: "9999",
            lifecycleCoordinator: device.coordinator))
        XCTAssertFalse(FileManager.default.fileExists(atPath: device.storeURL.path))
        XCTAssertEqual(try device.keychain.bytes(), before)
        let owner = WalletOwnerPIN(keystore: device.keychain, settings: device.settings, recoveryGate: device.isolatedGate())
        let grant = try owner.authorizeRetained("1234", addresses: [account.address])
        var interruptions: [(String, Installation)] = []
        try WalletPreservedGeneration.restore(folder: folder, paths: paths(device), settings: device.settings,
            keystore: device.keychain, grants: [grant], newPIN: "1234", lifecycleCoordinator: device.coordinator,
            checkpoint: { step in interruptions.append((step, try device.copy())) })
        XCTAssertTrue(interruptions.contains { $0.0 == "planned" })
        XCTAssertTrue(interruptions.contains { $0.0.hasPrefix("moved:") })
        XCTAssertTrue(interruptions.contains { $0.0 == "settingsRestored" })
        for (step, revived) in interruptions {
            XCTAssertEqual(try revived.startup(), .ready, step)
            XCTAssertEqual(try revived.keychain.bytes(), before, step)
            XCTAssertEqual(try KeySafetyStore.rows(at: revived.storeURL).map(\.address), [account.address], step)
            XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: revived.keychain), step)
            XCTAssertEqual(try revived.rootDecision(selected: account), [.localAuthentication], step)
        }
        XCTAssertEqual(try device.keychain.bytes(), before)
    }

    func testPreservedGenerationRejectsChangedFilesAndAnUnrelatedLiveWallet() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try KeySafetyStore.write([account], to: device.storeURL)
        device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        let paths = WalletLocalStateSetAside.Paths(storeURL: device.storeURL, applicationSupportURL: device.directory,
            setAsideRootURL: device.directory.appendingPathComponent("WalletSetAside"))
        let folder = try WalletLocalStateSetAside.setAside(settings: device.settings, expectedMarker: nil,
            paths: paths, lifecycleCoordinator: device.coordinator)
        let saved = folder.appendingPathComponent("CoreData/" + device.storeURL.lastPathComponent)
        let bytes = try Data(contentsOf: saved)
        try Data("modified".utf8).write(to: saved)
        XCTAssertTrue(WalletPreservedGeneration.available(paths: paths, settings: device.settings).isEmpty)
        try bytes.write(to: saved)
        try KeySafetyStore.write([account], to: device.storeURL)
        XCTAssertTrue(WalletPreservedGeneration.available(paths: paths, settings: device.settings).isEmpty)
        XCTAssertEqual(try Data(contentsOf: saved), bytes)
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

    func testMissingAppPINWithRetainedSigningRowsOpensRecoveryWithoutChangingKeys() throws {
        for selectedHasKeys in [true, false] {
            let device = try Installation()
            let retained = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
            let selected: AccountItem
            if selectedHasKeys {
                selected = retained
                try KeySafetyStore.write([retained], to: device.storeURL)
            } else {
                let other = try HistoricalWriter.phraseImport(phrase(entropy: 0x43, bytes: 16),
                    keystore: device.keychain.base)
                for tag in [KeystoreTag.secretKeyTagForAddress(other.address),
                            KeystoreTag.seedTagForAddress(other.address),
                            KeystoreTag.entropyTagForAddress(other.address),
                            KeystoreTag.deriviationTagForAddress(other.address)] {
                    if try device.keychain.checkKey(for: tag) { try device.keychain.deleteKey(for: tag) }
                }
                selected = other
                try KeySafetyStore.write([other, retained], to: device.storeURL)
            }
            let before = try device.keychain.bytes()
            XCTAssertEqual(try device.rootDecision(selected: selected), [.broken])
            XCTAssertTrue(device.settings.walletMigrationRecoveryRequired)
            XCTAssertEqual(try device.keychain.bytes(), before)
            XCTAssertThrowsError(try device.isolatedGate().requireMutableWalletAccess())
            XCTAssertEqual(Set(try KeySafetyStore.rows(at: device.storeURL).map(\.address)),
                selectedHasKeys ? [retained.address] : [retained.address, selected.address])
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
            KeystoreTag.deriviationTagForAddress(account.address), KeystoreTag.seedTagForAddress(account.address),
            WalletOwnerPIN.setupPrefix + account.address])
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

    func testRecoveryStillAddsProvenLegacyCopiesBeforeThe386Downgrade() throws {
        for watchOnly in [false, true] {
            let device = try Installation()
            let fixture = try XCTUnwrap(historicalVectors("ios-386-vectors").first { ($0["id"] as? String) == "ios-386-sr25519-15words-19" })
            let account = try historicalAccount(fixture)
            let entropy = try Data(hex: XCTUnwrap(fixture["entropyHex"] as? String))
            try device.keychain.base.addKey(entropy, with: KeystoreTag.legacyEntropy.rawValue)
            try KeySafetyStore.write([account], to: device.storeURL)
            device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
            if watchOnly { device.settings.set(value: true, for: "wallet.watchOnly.\(account.address)") }
            device.settings.setWalletMigrationRecovery(reason: "An unrelated integrity check remains unresolved")
            let marker = WalletMigrationRecoveryMarker.capture(device.settings)
            XCTAssertEqual(try device.startup(), .recoveryRequired)
            XCTAssertEqual(WalletMigrationRecoveryMarker.capture(device.settings), marker)
            XCTAssertThrowsError(try device.gate().requireMutableWalletAccess())
            XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.legacyEntropy.rawValue), entropy)
            if watchOnly {
                XCTAssertNil(try device.keychain.fetchSecretKeyForAddress(account.address))
                continue
            }
            XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.entropyTagForAddress(account.address)), entropy)
            XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain))
            let old = try AppStore386Launch.run(storeURL: device.storeURL, keystore: device.keychain.base, settings: device.settings)
            XCTAssertFalse(old.settingsWiped)
            XCTAssertFalse(try device.keychain.checkKey(for: KeystoreTag.legacyEntropy.rawValue))
            XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain))
        }
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
                KeystoreTag.seedTagForAddress(account.address), KeystoreTag.secretKeyTagForAddress(account.address),
                WalletOwnerPIN.setupPrefix + account.address])
        }
    }

    // MARK: (k) 3/6/9-word wallets imported by App Store 3.8.6

    func testTypedShortPhrasesRequireAndRestoreTheKnownAddressBeforeSaving() throws {
        for words in [3, 6, 9] {
            for crypto: CryptoType in [.sr25519, .ed25519, .ecdsa] {
                let phrase = try shortPhrase(words: words)
                let path = "//7"
                let oldKeys = InMemoryKeychain()
                let old = try HistoricalWriter.phraseImport(phrase, path: path, cryptoType: crypto,
                    keystore: oldKeys)
                let device = try Installation()
                let facade = UserDataStorageTestFacade()
                let selection = try device.selectedWalletSettings(facade: facade)
                let factory = AccountOperationFactory(keystore: device.keychain, recoveryGate: device.isolatedGate())
                let interactor = AccountImportInteractor(accountOperationFactory: factory,
                    accountRepository: AnyDataProviderRepository(facade.createRepository(
                        mapper: AnyCoreDataMapper(AccountItemMapper())) as CoreDataRepository<AccountItem, CDAccountItem>),
                    operationManager: OperationManager(), settings: selection,
                    keystoreImportService: KeystoreImportService(logger: Logger.shared), eventCenter: EventCenter.shared,
                    lifecycleCoordinator: device.coordinator)
                var request = AccountImportMnemonicRequest(mnemonic: phrase, username: "Historical", networkType: .sora,
                    derivationPath: path, cryptoType: crypto)
                // No address, an empty address, and a different address must all
                // fail before any account row or Keychain item is written.
                XCTAssertThrowsError(try interactor.prepareMnemonic(request))
                request.expectedAddress = "  "
                XCTAssertThrowsError(try interactor.prepareMnemonic(request))
                request.expectedAddress = "wrong-address"
                let wrong = try interactor.prepareMnemonic(request)
                wrong.start()
                XCTAssertThrowsError(try wrong.extractResultData(throwing: BaseOperationError.parentOperationCancelled))
                XCTAssertTrue(try device.keychain.bytes().isEmpty)
                XCTAssertNil(selection.currentAccount)
                request.expectedAddress = old.address
                // A missing derivation path cannot be accepted for this address.
                let missingPath = AccountImportMnemonicRequest(mnemonic: phrase, username: "Historical", networkType: .sora,
                    derivationPath: "", cryptoType: crypto, expectedAddress: old.address)
                let missing = try interactor.prepareMnemonic(missingPath)
                missing.start()
                XCTAssertThrowsError(try missing.extractResultData(throwing: BaseOperationError.parentOperationCancelled))
                XCTAssertTrue(try device.keychain.bytes().isEmpty)
                let completed = expectation(description: "typed historical import")
                var result: Result<AccountItem, Error>?
                interactor.importAccountWithMnemonic(request: request) { result = $0; completed.fulfill() }
                wait(for: [completed], timeout: 10)
                let imported = try XCTUnwrap(result).get()
                XCTAssertEqual(imported.address, old.address)
                XCTAssertEqual(try device.keychain.fetchSecretKeyForAddress(imported.address),
                    try oldKeys.fetchSecretKeyForAddress(old.address))
                XCTAssertTrue(try AppStore386Launch.canSign(imported, keystore: device.keychain.base))
                XCTAssertEqual(try device.networkStore().load()?.wallets.first?.secretSource, .rawSeed)
            }
        }
    }

    func testImportScreenForwardsPathPasswordAndKeyType() throws {
        let controller = ImportAccountViewController()
        let presenter = AccountImportPresenter(sourceType: .mnemonic, config: ApplicationConfig.shared)
        let interactor = LegacyUpgradeImportSpy()
        presenter.interactor = interactor
        presenter.view = controller
        controller.presenter = presenter
        controller.loadViewIfNeeded()
        presenter.didReceiveAccountImport(metadata: AccountImportMetadata(availableSources: AccountImportSource.allCases,
            defaultSource: .mnemonic, availableNetworks: [.sora], defaultNetwork: .sora,
            availableCryptoTypes: CryptoType.allCases, defaultCryptoType: .sr25519))
        func field(_ id: String) throws -> UITextField {
            var pending = [controller.view!]
            while let node = pending.popLast() {
                if node.accessibilityIdentifier == id, let field = node as? UITextField { return field }
                pending.append(contentsOf: node.subviews)
            }
            throw ImportAccountError.unexpectedError
        }
        let path = try field("wallet-import-derivation-path")
        path.text = "//7///test-password"
        path.sendActions(for: .editingChanged)
        presenter.selectCryptoType(.ecdsa)
        XCTAssertEqual(presenter.selectedCryptoType, .ecdsa)
        XCTAssertEqual(presenter.derivationPathViewModel?.inputHandler.value, "//7///test-password")
        let json = "{\"encoded\":\"public-test-placeholder\"}"
        presenter.didSuggestKeystore(text: json, preferredInfo: nil)
        XCTAssertEqual(presenter.sourceViewModel?.inputHandler.value, json)
        let password = try field("wallet-import-json-password")
        XCTAssertFalse(password.isHidden)
        XCTAssertTrue(password.isSecureTextEntry)
        password.text = "synthetic-json-password"
        password.sendActions(for: .editingChanged)
        XCTAssertEqual(presenter.passwordViewModel?.inputHandler.value, "synthetic-json-password")
    }

    func testTypedShortPhrasePresenterKeepsKnownAddressThroughValidationAndNameScreen() throws {
        let presenter = AccountImportPresenter(sourceType: .mnemonic, config: ApplicationConfig.shared)
        let interactor = LegacyUpgradeImportSpy()
        let wireframe = AccountImportWireframeSpy()
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        presenter.didReceiveAccountImport(metadata: AccountImportMetadata(availableSources: [.mnemonic],
            defaultSource: .mnemonic, availableNetworks: [.sora], defaultNetwork: .sora,
            availableCryptoTypes: [.sr25519], defaultCryptoType: .sr25519))
        presenter.sourceViewModel?.inputHandler.changeValue(to: try shortPhrase(words: 6))
        wireframe.knownAddressResponse = "known-wallet-address"
        presenter.proceed()
        XCTAssertEqual(wireframe.addressPrompts, 1)
        XCTAssertEqual(interactor.validationRequests.first?.expectedAddress, "known-wallet-address")
        XCTAssertEqual(wireframe.proceededAddress, "known-wallet-address")
        XCTAssertEqual(wireframe.proceeded, 1)
        // A failed identity check requires a new explicit address choice.
        presenter.didReceiveAccountImport(error: AccountCreateError.backupIdentityMismatch)
        wireframe.knownAddressResponse = nil
        presenter.proceed()
        XCTAssertEqual(wireframe.addressPrompts, 2)
        XCTAssertEqual(wireframe.proceeded, 1)
    }

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
            let setupTag = WalletOwnerPIN.setupPrefix + account.address
            XCTAssertEqual(device.keychain.added, [setupTag])
            let after = try device.keychain.bytes()
            XCTAssertEqual(Set(after.keys), Set(keys.keys).union([setupTag]))
            for (tag, bytes) in keys { XCTAssertEqual(after[tag], bytes, tag) }
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
        let originalSecret = try device.keychain.fetchKey(for: KeystoreTag.secretKeyTagForAddress(failing.address))
        try device.keychain.base.updateKey(Data(repeating: 9, count: 64),
                                           with: KeystoreTag.secretKeyTagForAddress(failing.address))
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
        try device.keychain.base.updateKey(originalSecret, with: KeystoreTag.secretKeyTagForAddress(failing.address))
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

        // A JSON-only import proves the secret independently of stale
        // auxiliary bytes. Add the absent secret and preserve those bytes.
        let conflicting = try Installation()
        try conflicting.keychain.base.addKey(Data("//0".utf8), with: KeystoreTag.deriviationTagForAddress(account.address))
        try conflicting.keychain.base.addKey(Data(repeating: 7, count: 16),
                                             with: KeystoreTag.entropyTagForAddress(account.address))
        let retained = try conflicting.keychain.bytes()
        let conflictingFactory = AccountOperationFactory(keystore: conflicting.keychain,
                                                         recoveryGate: conflicting.isolatedGate())
        let selection = try conflicting.selectedWalletSettings()
        let restored = try conflicting.insert(PreparedAccount(account: account, secretKey: secret, entropy: nil,
            seed: nil, derivationPath: nil, recoveryGate: conflicting.isolatedGate()), into: selection,
            factory: conflictingFactory)
        XCTAssertEqual(restored.address, account.address)
        XCTAssertEqual(conflicting.keychain.added, [KeystoreTag.secretKeyTagForAddress(account.address)])
        for (tag, bytes) in retained { XCTAssertEqual(try conflicting.keychain.fetchKey(for: tag), bytes) }
        XCTAssertFalse(conflicting.keychain.changedExistingItems)
        XCTAssertFalse(conflicting.settings.walletMigrationRecoveryRequired)
    }

    func testTwoReinstallsNeverPromoteNewAppPINToRetainedWalletOwnership() throws {
        let keys = InMemoryKeychain()
        let first = try HistoricalWriter.phraseImport(phrase12, keystore: keys)
        let original = try keys.fetchSecretKeyForAddress(first.address)
        let settings = InMemorySettingsManager()
        let gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        WalletPendingPinSetup.begin(settings)
        let owner = WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate)
        try owner.prepareInitialSetup(account: first, operationID: UUID())
        try owner.setInitialPIN("111111", accounts: [first])
        let firstBinding = try keys.fetchKey(for: first.address + WalletOwnerPIN.bindingSuffix)
        // First reinstall: no old rows. Creating an attacker's wallet proves only that wallet.
        let reinstalled = InMemorySettingsManager()
        let attacker = try HistoricalWriter.phraseImport(phrase(entropy: 0x61, bytes: 16), keystore: keys)
        WalletPendingPinSetup.begin(reinstalled)
        let newOwner = WalletOwnerPIN(keystore: keys, settings: reinstalled, recoveryGate: gate)
        try newOwner.prepareInitialSetup(account: attacker, operationID: UUID())
        try newOwner.setInitialPIN("222222", accounts: [attacker])
        XCTAssertEqual(try keys.fetchKey(for: first.address + WalletOwnerPIN.bindingSuffix), firstBinding)
        // Second reinstall: pincode is now the attacker's. It still owns only the attacker's wallet.
        let again = WalletOwnerPIN(keystore: keys, settings: InMemorySettingsManager(), recoveryGate: gate)
        XCTAssertEqual(try again.verifyRetained("222222", addresses: [first.address, attacker.address]), [attacker.address])
        XCTAssertEqual(try again.verifyRetained("111111", addresses: [first.address, attacker.address]), [first.address])
        XCTAssertEqual(try keys.fetchSecretKeyForAddress(first.address), original)
        XCTAssertFalse(try keys.allKeyIdentifiers().contains { $0.hasPrefix(WalletRetainedPinGate.earlierInstallPinTagPrefix) })
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
        // backup's own address; typed imports require an explicit known address.
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
        XCTAssertTrue(device.keychain.added.isEmpty)
        XCTAssertTrue(WalletPendingPinSetup.isPending(device.settings))
        XCTAssertFalse(device.keychain.changedExistingItems)
    }

    @MainActor
    private func makeWelcomeBackWindow() -> (window: UIWindow, cleanup: () -> Void) {
        let previousWindow = UIApplication.shared.keyWindow
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        window.frame = UIScreen.main.bounds
        return (window, {
            window.isHidden = true
            window.rootViewController = nil
            window.windowScene = nil
            previousWindow?.makeKeyAndVisible()
            UIView.setAnimationsEnabled(animationsWereEnabled)
        })
    }

    private func welcomeBackDescendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(welcomeBackDescendants)
    }

    @MainActor
    func testCancelledWelcomeBackRestoreDoesNotChangeTheNextSetupDestination() throws {
        for identifier in ["wallet-welcome-back-phrase", "wallet-welcome-back-drive"] {
            let (window, cleanup) = makeWelcomeBackWindow()
            defer { cleanup() }
            let settings = InMemorySettingsManager()
            var onboardingCount = 0
            var restoreRequests: [Bool] = []
            let controller = WalletWelcomeBackViewController(
                keystore: InMemoryKeychain(), settings: settings,
                onContinueToOnboarding: { onboardingCount += 1 },
                onWalletsRestored: { XCTFail("No retained-wallet restore was chosen") },
                onRestore: { restoreRequests.append($0) })
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.loadViewIfNeeded()
            controller.apply(WalletRecoveryState.welcomeBack(
                adoptableWallets: 1, walletsWithPhrase: 1, retainedPinUsable: true).options)
            let button = try XCTUnwrap(welcomeBackDescendants(controller.view).first {
                $0.accessibilityIdentifier == identifier
            } as? UIButton)
            button.sendActions(for: .touchUpInside)
            let prompt = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
            XCTAssertTrue(prompt.actions.contains { $0.style == .cancel })
            XCTAssertEqual(onboardingCount, 0)
            XCTAssertTrue(restoreRequests.isEmpty)
            XCTAssertFalse(WalletPendingPinSetup.isPending(settings))
            // Cancel has no side effects. Dismiss the prompt without selecting
            // either continuation, then exercise confirmed new-device setup's
            // normal onboarding entry point without another retained-wallet prompt.
            prompt.dismiss(animated: false)
            spinRunLoop { controller.presentedViewController == nil }
            XCTAssertNil(controller.presentedViewController)
            controller.apply(WalletRecoveryState.welcomeBack(
                adoptableWallets: 0, walletsWithPhrase: 0, retainedPinUsable: false).options)
            controller.leaveForOnboarding()
            spinRunLoop { onboardingCount > 0 || !restoreRequests.isEmpty }
            XCTAssertEqual(onboardingCount, 1, identifier)
            XCTAssertTrue(restoreRequests.isEmpty, "A cancelled restore cannot replace new wallet setup")
            XCTAssertTrue(WalletPendingPinSetup.isPending(settings))
        }
    }

    @MainActor
    func testWelcomeBackExplicitRestoreChoicesKeepTheirDestination() throws {
        for (identifier, drive) in [("wallet-welcome-back-phrase", false), ("wallet-welcome-back-drive", true)] {
            let (window, cleanup) = makeWelcomeBackWindow()
            defer { cleanup() }
            let settings = InMemorySettingsManager()
            var restoreRequests: [Bool] = []
            let controller = WalletWelcomeBackViewController(
                keystore: InMemoryKeychain(), settings: settings,
                onContinueToOnboarding: { XCTFail("An explicit restore must open the chosen import") },
                onWalletsRestored: { XCTFail("No retained-wallet restore was chosen") },
                onRestore: { restoreRequests.append($0) })
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.loadViewIfNeeded()
            let button = try XCTUnwrap(welcomeBackDescendants(controller.view).first {
                $0.accessibilityIdentifier == identifier
            } as? UIButton)
            button.sendActions(for: .touchUpInside)
            spinRunLoop { !restoreRequests.isEmpty }
            XCTAssertEqual(restoreRequests, [drive])
            XCTAssertTrue(WalletPendingPinSetup.isPending(settings))
        }
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
        try saveOwnerBindingFixture("111111", accounts: [other], keystore: device.keychain.base)
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
            config: ApplicationConfig.shared, ownerPINKeystore: restarted.keychain,
            recoveryGate: restarted.isolatedGate(), accounts: { [imported] })
        interactor.presenter = output
        interactor.process(pin: "222222")
        wait(for: [saved], timeout: 10)
        XCTAssertTrue(output.errors.isEmpty)
        XCTAssertEqual(try restarted.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("222222".utf8))
        XCTAssertFalse(WalletPendingPinSetup.isPending(restarted.settings))
        XCTAssertEqual(try restarted.rootDecision(selected: imported), [.localAuthentication])
        XCTAssertEqual(try WalletRetainedPinGate.verify("111111", keystore: restarted.keychain,
            settings: restarted.settings, scope: .afterSetup), [other.address])
        XCTAssertEqual(try WalletRetainedPinGate.verify("222222", keystore: restarted.keychain,
            settings: restarted.settings, scope: .afterSetup), [imported.address])
        XCTAssertEqual(WalletRecoveryStateProbe.retainedWalletsAfterSetup(keystore: restarted.keychain,
            existingAddresses: [imported.address], recoveryGate: restarted.isolatedGate()).map(\.address),
            [other.address])
    }

    /// Leaving Welcome back needs a stored copy of the earlier PIN. Every
    /// distinct PIN gets one (no limit); when the copy cannot be saved,
    /// Welcome back stays, PIN setup stops, and the earlier PIN is unchanged.
    func testUnbound386WalletsAndLegacyPinCopiesNeverAuthorizeRestoration() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        for (index, pin) in ["111111", "222222", "333333", "444444"].enumerated() {
            try device.keychain.base.addKey(Data(pin.utf8), with: "earlierInstallPin-\(index + 1)")
        }
        try device.keychain.base.addKey(Data("555555".utf8), with: KeystoreTag.pincode.rawValue)
        let before = try device.keychain.bytes()
        for pin in ["111111", "222222", "555555"] {
            XCTAssertThrowsError(try WalletRetainedPinGate.verify(pin, keystore: device.keychain,
                settings: device.settings, addresses: [account.address])) {
                XCTAssertEqual($0 as? WalletRetainedPinGate.Failure, .noRetainedPin)
            }
        }
        try WalletPendingPinSetup.leaveWelcomeBack(keystore: device.keychain, settings: device.settings)
        XCTAssertTrue(WalletPendingPinSetup.isPending(device.settings))
        XCTAssertEqual(try device.keychain.bytes(), before)
        XCTAssertTrue(device.keychain.added.isEmpty)
        // A failed initial journal write never reports PIN setup success or changes the old PIN.
        let failing = AddFailingKeychain()
        let fresh = try HistoricalWriter.phraseImport(phrase12, keystore: failing.base)
        try failing.base.addKey(Data("777777".utf8), with: KeystoreTag.pincode.rawValue)
        let settings = InMemorySettingsManager()
        WalletPendingPinSetup.begin(settings)
        try WalletOwnerPIN(keystore: failing.base, settings: settings)
            .prepareInitialSetup(account: fresh, operationID: UUID())
        let output = PinSetupOutputSpy()
        let interactor = PinSetupInteractor(secretManager: KeystoreSecretManager(failing), settingsManager: settings,
            biometryAuth: KeySafetyNoBiometry(), config: ApplicationConfig.shared, ownerPINKeystore: failing,
            recoveryGate: WalletRecoveryCapabilityGate(settings: settings,
                unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false }), accounts: { [fresh] })
        interactor.presenter = output
        interactor.process(pin: "888888")
        spinRunLoop(until: { !output.errors.isEmpty }, timeout: 10)
        XCTAssertFalse(output.errors.isEmpty)
        XCTAssertEqual(interactor.state, .waitingPincode)
        XCTAssertTrue(WalletPendingPinSetup.isPending(settings))
        XCTAssertEqual(try failing.fetchKey(for: KeystoreTag.pincode.rawValue), Data("777777".utf8))
    }

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

    /// Validate the actual add-account route before it decides which screen to
    /// open: new and keyless imports continue normally; conflicts need consent.
    @MainActor
    func testAddAccountValidationDistinguishesNewMissingHealthyAndConflictingRows() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try KeySafetyStore.write([account], to: device.storeURL)
        XCTAssertEqual(try device.startup(), .ready)
        let facade = UserDataStorageTestFacade()
        let selection = try device.selectedWalletSettings(accounts: [account], facade: facade)
        let repository: CoreDataRepository<AccountItem, CDAccountItem> =
            facade.createRepository(mapper: AnyCoreDataMapper(AccountItemMapper()))
        let interactor = AddAccountImportInteractor(
            accountOperationFactory: AccountOperationFactory(keystore: device.keychain, recoveryGate: device.isolatedGate()),
            accountRepository: AnyDataProviderRepository(repository), operationManager: OperationManager(),
            settings: selection, keystoreImportService: KeystoreImportService(logger: Logger.shared),
            eventCenter: EventCenter(), lifecycleCoordinator: device.coordinator)
        let controller = UIViewController()
        interactor.credentialRepairFlow = WalletMissingAccountRepairFlow(controller: controller,
            keystore: device.keychain, selection: selection)
        func validate(_ phrase: String) throws -> AccountItem? {
            let done = expectation(description: "validated actual import")
            var outcome: Result<AccountItem?, Error>?
            interactor.validateAccountWithMnemonic(request: AccountImportMnemonicRequest(mnemonic: phrase,
                username: "Public import", networkType: .sora, derivationPath: "", cryptoType: .sr25519)) {
                    outcome = $0; done.fulfill()
                }
            wait(for: [done], timeout: 20)
            return try XCTUnwrap(outcome).get()
        }
        XCTAssertNil(try validate(phrase(entropy: 0x47, bytes: 16)))
        XCTAssertThrowsError(try validate(phrase12)) { error in
            guard case AccountCreateError.duplicated = error else { return XCTFail("Wrong duplicate result") }
        }
        for tag in [KeystoreTag.secretKeyTagForAddress(account.address),
                    KeystoreTag.entropyTagForAddress(account.address), KeystoreTag.seedTagForAddress(account.address)] {
            try device.keychain.base.deleteKey(for: tag)
        }
        XCTAssertNil(try validate(phrase12), "A keyless new-phone restore must not require an unavailable old PIN")
        try device.keychain.base.saveKey(Data([0xff]), with: KeystoreTag.secretKeyTagForAddress(account.address))
        let before = try device.keychain.bytes()
        XCTAssertEqual(try validate(phrase12)?.address, account.address)
        XCTAssertEqual(try device.keychain.bytes(), before, "Validation itself never repairs retained material")
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
    var validationRequests: [AccountImportMnemonicRequest] = []
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
                                     completion: ((Result<AccountItem?, Error>?) -> Void)?) {
        validationRequests.append(request)
        completion?(.success(nil))
    }
    func validateAccountWithSeed(request: AccountImportSeedRequest,
                                 completion: ((Result<AccountItem?, Error>?) -> Void)?) {}
    func validateAccountWithKeystore(request: AccountImportKeystoreRequest,
                                     completion: ((Result<AccountItem?, Error>?) -> Void)?) {}
    func deriveMetadataFromKeystore(_ keystore: String) {}
    func importBackedupAccount(request: AccountImportBackedupRequest) {}
}

private final class AccountImportWireframeSpy: AccountImportWireframeProtocol {
    var proceeded = 0
    var proceededAddress: String?
    var knownAddressResponse: String?
    var addressPrompts = 0
    func requestKnownAddress(from view: AccountImportViewProtocol?, completion: @escaping (String?) -> Void) {
        addressPrompts += 1
        completion(knownAddressResponse)
    }
    var errors: [Error] = []
    func proceed(from view: AccountImportViewProtocol?, sourceType: AccountImportSource, cryptoType: CryptoType,
                 networkType: Chain, sourceViewModel: InputViewModelProtocol, usernameViewModel: InputViewModelProtocol,
                 passwordViewModel: InputViewModelProtocol?, derivationPathViewModel: InputViewModelProtocol?,
                 expectedAddress: String?) {
        proceededAddress = expectedAddress
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

/// App Store 3.8.6 (`354f176c`) `AccountOptionsInteractor.updateUsername(_:)`,
/// over this data:
///
///     let account = self.account.replacingUsername(username)
///     let updateOperation = accountRepository.saveOperation {
///         [account]
///     } _: {
///         []
///     }
///
/// Only the account row is saved. 3.8.6 knows no network snapshot, so the
/// snapshot keeps the earlier name.
private enum AppStore386Rename {
    static func updateUsername(_ username: String, of account: AccountItem, storeURL: URL) throws {
        let facade = try OnDiskUserDataFacade(storeURL: storeURL)
        defer { try? facade.close() }
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            facade.createRepository(mapper: AnyCoreDataMapper(AccountItemMapper()))
        let account = account.replacingUsername(username)
        let updateOperation = accountRepository.saveOperation {
            [account]
        } _: {
            []
        }
        OperationQueue().addOperations([updateOperation], waitUntilFinished: true)
        try updateOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }
}

/// A directory listing taken an instant before a write of another file in
/// the folder finished and removed its helper file: the listing names an
/// entry that is gone when it is examined.
private final class StaleListingFileManager: FileManager {
    var vanished: [URL] = []

    override func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?,
                                      options mask: FileManager.DirectoryEnumerationOptions = []) throws -> [URL] {
        try super.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask) + vanished
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
    ///
    /// - Parameter verify: further checks on the revived installation after
    ///   its first launch.
    private func assertNextLaunchCompletes(_ state: KilledInstallation, accounts: [AccountItem],
                                           file: StaticString = #filePath, line: UInt = #line,
                                           verify: (Installation) throws -> Void = { _ in }) throws {
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
            try verify(revived)
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
            let done = DispatchSemaphore(value: 0)
            DispatchQueue.global(qos: .userInteractive).async {
                defer { done.signal() }
                sweep = DurableFileWriter.sweepLeftovers(in: directory)
                listed = ((try? DurableFileWriter.contentsIgnoringLeftovers(
                    of: directory, fileManager: .default, includingPropertiesForKeys: nil)) ?? [])
                    .map(\.lastPathComponent)
            }
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
        records.apply(options(unreadable: true))
        let body = try XCTUnwrap(descendants(records.view).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == "wallet-recovery-body" }?.text)
        XCTAssertTrue(body.contains(diagnostic.userMessage))
        XCTAssertTrue(body.contains(WalletUX.text("Contact SORA support if you need help. Never share your recovery phrase, private key or PIN.")))
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

// MARK: - ik2-leftover-files, review round 2

extension WalletInterruptedWriteTests {
    private func descendants(_ view: UIView) -> [UIView] { view.subviews + view.subviews.flatMap(descendants) }

    private func button(_ identifier: String, in controller: UIViewController) throws -> UIButton {
        try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == identifier }, identifier)
    }

    private func bodyText(of controller: UIViewController) throws -> String {
        try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == "wallet-recovery-body" }?.text)
    }

    // MARK: 8. A rename: the display name follows the database

    func testAKillAtAnyStepOfARenameIsCompletedByTheNextLaunchWithTheNewName() throws {
        let (device, first, second) = try upgradedTwoAccountDevice()
        XCTAssertEqual(try device.startup(), .ready)
        // The app's own stack over the installation's database file: the
        // rename commits the row there first, then writes the snapshot.
        let facade = try OnDiskUserDataFacade(storeURL: device.storeURL)
        let selection = try device.selectedWalletSettings(facade: facade)
        var renamed: Result<AccountItem, Error>?
        let states = try InterruptedWrite.killStates(of: device, label: "rename") {
            let done = DispatchSemaphore(value: 0)
            selection.performUpdateName(account: second, displayName: "Renamed") { result in
                renamed = result
                done.signal()
            }
            done.wait()
        }
        XCTAssertEqual(try XCTUnwrap(renamed).get().username, "Renamed")
        try facade.close()
        // A new snapshot file (4 steps), then the pointer over the old one
        // (7 steps). Every one of them comes after the row was saved.
        XCTAssertEqual(states.count, 11)
        var sawTheEarlierNameInTheSnapshot = false
        for state in states {
            let killed = try state.revive()
            XCTAssertEqual(try KeySafetyStore.rows(at: killed.storeURL).map(\.username), ["First", "Renamed"],
                           state.label)
            // The snapshot is read as the next launch reads it, after the sweep.
            WalletInterruptedWriteCleanup.run(storeURL: killed.storeURL, applicationSupportURL: killed.directory)
            if try killed.networkStore().load()?.wallets.map(\.displayName) == ["First", "Second"] {
                sawTheEarlierNameInTheSnapshot = true
            }
            try assertNextLaunchCompletes(state, accounts: [first, second]) { revived in
                XCTAssertEqual(try KeySafetyStore.rows(at: revived.storeURL).map(\.username), ["First", "Renamed"],
                               state.label)
                let snapshot = try XCTUnwrap(revived.networkStore().load(), state.label)
                XCTAssertEqual(snapshot.wallets.map(\.id), [first.address, second.address], state.label)
                XCTAssertEqual(snapshot.wallets.map(\.displayName), ["First", "Renamed"], state.label)
                XCTAssertEqual(snapshot.selectedWalletId, first.address, state.label)
            }
        }
        XCTAssertTrue(sawTheEarlierNameInTheSnapshot)
    }

    func testARenameWhoseSnapshotWriteFailsIsCompletedByTheNextLaunch() throws {
        struct DiskFull: Error {}
        // The snapshot write fails at its first step, or the pointer write does.
        for failingCheckpoint in [0, 4] {
            let label = "fails at checkpoint \(failingCheckpoint)"
            let (device, first, second) = try upgradedTwoAccountDevice()
            XCTAssertEqual(try device.startup(), .ready, label)
            let keys = try device.keychain.bytes()
            let facade = try OnDiskUserDataFacade(storeURL: device.storeURL)
            let selection = try device.selectedWalletSettings(facade: facade)
            var renamed: Result<AccountItem, Error>?
            var reached = 0
            try InterruptedWrite.observing(below: device.directory, { _, _ in
                defer { reached += 1 }
                if reached == failingCheckpoint { throw DiskFull() }
            }, during: {
                let done = DispatchSemaphore(value: 0)
                selection.performUpdateName(account: first, displayName: "Renamed") { result in
                    renamed = result
                    done.signal()
                }
                done.wait()
            })
            try facade.close()
            XCTAssertThrowsError(try XCTUnwrap(renamed).get(), label)
            // The row has the new name, the snapshot the earlier one, and the
            // failure is recorded as one the next launch retries.
            XCTAssertEqual(try KeySafetyStore.rows(at: device.storeURL).map(\.username), ["Renamed", "Second"], label)
            XCTAssertEqual(try device.networkStore().load()?.wallets.map(\.displayName), ["First", "Second"], label)
            XCTAssertTrue(device.settings.walletMigrationRecoveryRequired, label)
            XCTAssertTrue(WalletMigrationRecoveryMarker.capture(device.settings).isRetryableStartupFailure, label)
            XCTAssertEqual(InterruptedWrite.helperFiles(under: device.directory), [], label)

            // The next launch brings the snapshot up to date and clears it.
            XCTAssertEqual(try device.startup(), .ready, label)
            XCTAssertFalse(device.settings.walletMigrationRecoveryRequired, label)
            let snapshot = try XCTUnwrap(device.networkStore().load(), label)
            XCTAssertEqual(snapshot.wallets.map(\.displayName), ["Renamed", "Second"], label)
            XCTAssertEqual(snapshot.wallets.map(\.id), [first.address, second.address], label)
            XCTAssertEqual(try device.keychain.bytes(), keys, label)
            XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems, label)
            XCTAssertTrue(try AppStore386Launch.canSign(first, keystore: device.keychain), label)
            XCTAssertEqual(try device.startup(), .ready, label)
            XCTAssertEqual(try device.networkStore().load(), snapshot, label)
        }
    }

    func testAnAccountRenamedInAppStore386OpensWithTheNewName() throws {
        for latchedByAnEarlierBuild in [false, true] {
            let label = "latched: \(latchedByAnEarlierBuild)"
            let (device, first, second) = try upgradedTwoAccountDevice()
            XCTAssertEqual(try device.startup(), .ready, label)
            let before = try XCTUnwrap(device.networkStore().load(), label)
            let keys = try device.keychain.bytes()

            // App Store 3.8.6 runs over this data again and the user renames
            // the selected account there.
            let row = try XCTUnwrap(KeySafetyStore.rows(at: device.storeURL).first { $0.address == first.address })
            try AppStore386Rename.updateUsername("Renamed in 3.8.6", of: row, storeURL: device.storeURL)
            XCTAssertEqual(try KeySafetyStore.rows(at: device.storeURL).map(\.username),
                           ["Renamed in 3.8.6", "Second"], label)
            XCTAssertEqual(try AppStore386Launch.run(storeURL: device.storeURL, keystore: device.keychain.base,
                settings: device.settings).selected?.address, first.address, label)
            XCTAssertEqual(try device.networkStore().load(), before, label)
            if latchedByAnEarlierBuild {
                // What 3.9.0 builds before this fix recorded here, on every launch.
                device.settings.setWalletMigrationRecovery(reason: UserStorageMigrationError
                    .privacySafeRecoveryDescription(for: WalletNetworkMigrationError.snapshotVerificationFailed))
            }

            // Back in this version: the wallet opens with the new name.
            XCTAssertEqual(try device.startup(), .ready, label)
            XCTAssertFalse(device.settings.walletMigrationRecoveryRequired, label)
            let snapshot = try XCTUnwrap(device.networkStore().load(), label)
            XCTAssertEqual(snapshot.wallets.map(\.displayName), ["Renamed in 3.8.6", "Second"], label)
            // Nothing but the name changed.
            XCTAssertEqual(snapshot.wallets.map(\.id), before.wallets.map(\.id), label)
            XCTAssertEqual(snapshot.wallets.map(\.existingSoraAddress), before.wallets.map(\.existingSoraAddress), label)
            XCTAssertEqual(snapshot.wallets.map(\.secretSource), before.wallets.map(\.secretSource), label)
            XCTAssertEqual(snapshot.accounts, before.accounts, label)
            XCTAssertEqual(snapshot.selectedWalletId, before.selectedWalletId, label)
            XCTAssertEqual(try device.keychain.bytes(), keys, label)
            XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems, label)
            for account in [first, second] {
                XCTAssertTrue(try AppStore386Launch.canSign(account, keystore: device.keychain), label)
                XCTAssertEqual(try keyStatus(account, on: device), .available, label)
            }
            // The launch after that one has nothing more to record.
            XCTAssertEqual(try device.startup(), .ready, label)
            XCTAssertEqual(try device.networkStore().load(), snapshot, label)
        }
    }

    // MARK: 9. An in-place restore of a 3, 6 or 9-word phrase

    func testAKillDuringAnInPlaceRestoreOfAShortPhraseIsCompletedByTheNextLaunch() throws {
        for words in [3, 6, 9] {
            for survivingAdds in [1, 2] {
                let label = "\(words) words, dies after \(survivingAdds) Keychain write(s)"
                let short = try shortPhrase(words: words)
                let original = try Installation()
                let first = try HistoricalWriter.phraseImport(phrase12, username: "First", order: 0,
                                                              isSelected: true, keystore: original.keychain.base)
                let second = try HistoricalWriter.phraseImport(short, username: "Second", order: 1,
                                                               isSelected: false, keystore: original.keychain.base)
                try KeySafetyStore.write([first, second], to: original.storeURL)
                XCTAssertEqual(try original.startup(), .ready, label)
                // A new iPhone: the files came back, the keys did not.
                let restored = try Installation()
                try FileManager.default.removeItem(at: restored.directory)
                try FileManager.default.copyItem(at: original.directory, to: restored.directory)
                XCTAssertEqual(try restored.startup(), .ready, label)
                XCTAssertEqual(try keyStatus(second, on: restored), .keysMissing, label)
                let selection = try restored.selectedWalletSettings(accounts: [first, second])

                // Add account > the Google Drive backup App Store 3.8.6 made
                // of the short phrase; the process dies between two Keychain
                // writes. (`BaseAccountImportInteractor.importAccount` prepares
                // such a backup with this same operation.)
                let dying = DyingKeychain(base: restored.keychain, survivingAdds: survivingAdds)
                let factory = AccountOperationFactory(keystore: dying, recoveryGate: restored.isolatedGate())
                let operation = factory.prepareAccountOperation(
                    request: AccountCreationRequest(username: "Imported", type: .sora, derivationPath: "",
                                                    cryptoType: .sr25519),
                    mnemonic: try IRMnemonicCreator(language: .english).mnemonic(fromList: short))
                operation.start()
                let prepared = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                XCTAssertEqual(prepared.account.address, second.address, label)
                XCTAssertThrowsError(try restored.insert(prepared, into: selection, factory: factory), label)
                XCTAssertTrue(dying.isDead, label)
                // The seed, which proves the account by itself, goes first;
                // the short entropy, which proves and derives nothing, second.
                XCTAssertEqual(restored.keychain.added, Array([KeystoreTag.seedTagForAddress(second.address),
                    KeystoreTag.entropyTagForAddress(second.address)].prefix(survivingAdds)), label)
                XCTAssertTrue(restored.keychain.deleted.isEmpty, label)

                // The next launch finds an account its seed proves and adds
                // the signing key. No second import, no removal.
                XCTAssertEqual(try restored.startup(), .ready, label)
                XCTAssertFalse(restored.settings.walletMigrationRecoveryRequired, label)
                XCTAssertEqual(try keyStatus(second, on: restored), .available, label)
                XCTAssertTrue(try AppStore386Launch.canSign(second, keystore: restored.keychain), label)
                for tag in [KeystoreTag.seedTagForAddress(second.address),
                            KeystoreTag.secretKeyTagForAddress(second.address)] {
                    XCTAssertEqual(try restored.keychain.fetchKey(for: tag),
                                   try original.keychain.fetchKey(for: tag), "\(label): \(tag.suffix(10))")
                }
                XCTAssertFalse(restored.keychain.changedExistingItems, label)
            }
        }
    }

    // MARK: 10. An import cut short, then the account removed in App Store 3.8.6

    func testAnImportCutShortAndThenRemovedInAppStore386DoesNotLockTheOtherAccounts() throws {
        for stage in [WalletAccountCommitStage.coreDataCommitted, .networkModelActivated] {
            let label = "journal at \(stage.rawValue)"
            let device = try Installation()
            let existing = try HistoricalWriter.phraseImport(try phrase(entropy: 2, bytes: 16), username: "Existing",
                order: 0, isSelected: true, keystore: device.keychain.base)
            try KeySafetyStore.write([existing], to: device.storeURL)
            XCTAssertEqual(try device.startup(), .ready, label)

            // An import of a second account is cut short after its row was
            // saved (`SelectedWalletSettings.performInsertAndSelect`: keys,
            // journal, rows, then the network model).
            let gate = device.isolatedGate()
            let journals = try WalletAccountCommitJournalStore(baseURL: device.directory, recoveryGate: gate)
            let imported = try HistoricalWriter.phraseImport(phrase12, username: "New", order: 1, isSelected: true,
                                                             keystore: device.keychain.base)
            var journal = try journals.begin(walletId: imported.address, existingWalletIds: [existing.address])
            journal = try journals.advance(journal, to: .secretsPersisted)
            let rows = [AccountItem(address: existing.address, cryptoType: existing.cryptoType,
                                    networkType: existing.networkType, username: existing.username,
                                    publicKeyData: existing.publicKeyData, settings: existing.settings,
                                    order: existing.order, isSelected: false), imported]
            let facade = try OnDiskUserDataFacade(storeURL: device.storeURL)
            try facade.save(rows)
            try facade.close()
            journal = try journals.advance(journal, to: .coreDataCommitted)
            if stage == .networkModelActivated {
                try WalletNetworkModelMigrator(keystore: device.keychain, store: device.networkStore(),
                    settings: device.settings, lifecycleCoordinator: device.coordinator, recoveryGate: gate)
                    .migrate(accounts: rows, selectedAddress: imported.address)
                journal = try journals.advance(journal, to: .networkModelActivated)
                XCTAssertEqual(try device.networkStore().load()?.wallets.count, 2, label)
            }
            XCTAssertEqual(try journals.unresolved().map(\.stage), [stage], label)

            // The next run is App Store 3.8.6 (the TestFlight build expired).
            // The account has its row and keys there, and the user removes it.
            XCTAssertEqual(try AppStore386Launch.run(storeURL: device.storeURL, keystore: device.keychain.base,
                settings: device.settings).selected?.address, imported.address, label)
            try AppStore386Removal.logoutAndClean(imported, storeURL: device.storeURL, keystore: device.keychain.base)
            XCTAssertEqual(try KeySafetyStore.rows(at: device.storeURL).map(\.address), [existing.address], label)
            let keys = try device.keychain.bytes()

            // Back in this version: the journal names an account the database
            // no longer has. The remaining account opens.
            XCTAssertEqual(try device.startup(), .ready, label)
            XCTAssertFalse(device.settings.walletMigrationRecoveryRequired, label)
            XCTAssertEqual(try journals.journalsForLegacyRecovery().map(\.stage), [.abandoned], label)
            XCTAssertEqual(try journals.unresolved().count, 0, label)
            let snapshot = try XCTUnwrap(device.networkStore().load(), label)
            XCTAssertEqual(snapshot.wallets.map(\.id), [existing.address], label)
            XCTAssertEqual(snapshot.selectedWalletId, existing.address, label)
            XCTAssertTrue(try AppStore386Launch.canSign(existing, keystore: device.keychain), label)
            XCTAssertEqual(try keyStatus(existing, on: device), .available, label)
            // The removed account's items are exactly what 3.8.6 left.
            XCTAssertEqual(try device.keychain.bytes(), keys, label)
            XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems, label)
            XCTAssertEqual(try device.startup(), .ready, label)
            // A new import is not blocked by the closed journal.
            let again = try device.importPhrase(try phrase(entropy: 7, bytes: 16),
                                                into: device.selectedWalletSettings(accounts: [existing]))
            XCTAssertNotEqual(again.address, existing.address, label)
        }

        // A journal whose row is gone from a database with no account at all
        // is not that state: it still stops, and nothing is closed.
        let device = try Installation()
        let imported = try HistoricalWriter.phraseImport(phrase12, username: "Only", order: 0, isSelected: true,
                                                         keystore: device.keychain.base)
        try KeySafetyStore.write([], to: device.storeURL)
        let journals = try WalletAccountCommitJournalStore(baseURL: device.directory,
                                                           recoveryGate: device.isolatedGate())
        var journal = try journals.begin(walletId: imported.address, existingWalletIds: [])
        journal = try journals.advance(journal, to: .secretsPersisted)
        journal = try journals.advance(journal, to: .coreDataCommitted)
        XCTAssertThrowsError(try OrdinaryWalletAccountCommitRecovery.resolve(journals: [journal],
            storeURL: device.storeURL, modelDirectory: UserStorageParams.modelDirectory, keystore: device.keychain,
            settings: device.settings, journalStore: journals, networkStore: device.networkStore(),
            recoveryGate: device.isolatedGate())) { error in
            guard case OrdinaryWalletAccountCommitRecovery.Failure.committedAccountMissing = error else {
                return XCTFail("\(error)")
            }
        }
        XCTAssertEqual(try journals.unresolved().map(\.stage), [.coreDataCommitted])
        // The ordinary transitions are as strict as before.
        XCTAssertThrowsError(try journals.advance(journal, to: .abandoned))
    }

    // MARK: 11. A database with no account beside a snapshot that lists wallets

    func testADatabaseWithNoAccountBesideASnapshotIsNotTakenForRemovedAccounts() throws {
        let (device, first, second) = try upgradedTwoAccountDevice()
        XCTAssertEqual(try device.startup(), .ready)
        let before = try XCTUnwrap(device.networkStore().load())
        XCTAssertEqual(before.wallets.count, 2)
        // Every row goes while the database file and its verified safety
        // backup stay (App Store 3.8.6 removing the last account, killed
        // after the row was deleted and before the database was dropped).
        try AppStore386Removal.logoutAndClean(second, storeURL: device.storeURL, keystore: device.keychain.base)
        try AppStore386Removal.logoutAndClean(first, storeURL: device.storeURL, keystore: device.keychain.base)
        XCTAssertEqual(try KeySafetyStore.rows(at: device.storeURL).count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: device.storeURL.path))
        let keys = try device.keychain.bytes()

        // The snapshot is not emptied: it is what still says a wallet existed.
        XCTAssertThrowsError(try device.startup()) { error in
            guard case WalletNetworkMigrationError.legacyIdentityMismatch = error else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(try device.networkStore().load(), before)
        XCTAssertEqual(try snapshotNames(device).count, 1)
        XCTAssertEqual(try device.keychain.bytes(), keys)
        XCTAssertTrue(device.keychain.added.isEmpty && !device.keychain.changedExistingItems)
    }

    // MARK: 12. A helper file that is gone when it is examined

    func testAHelperFileThatVanishesBetweenTheListingAndItsCheckIsLeftOut() throws {
        let directory = try makeDirectory()
        let store = try Sora2PendingSubmissionStore(baseURL: directory)
        _ = try store.stage(account: "cnAccount", hash: transactionHash(0xa1))
        let folder = directory.appendingPathComponent("SORA/PendingTransactions")
        // A write of another journal in this folder was in progress when the
        // folder was listed and has finished (its helper file is gone) by
        // the time the entry is examined.
        let manager = StaleListingFileManager()
        manager.vanished = [
            folder.appendingPathComponent(".durable-\(UUID().uuidString).tmp"),
            folder.appendingPathComponent(".durable-rollback-\(UUID().uuidString).anchor"),
        ]
        XCTAssertEqual(try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).count, 3)
        XCTAssertEqual(try DurableFileWriter.contentsIgnoringLeftovers(of: folder, fileManager: manager,
            includingPropertiesForKeys: nil).map(\.lastPathComponent), ["sora2-signed-v1.json"])
        XCTAssertNoThrow(try PendingTransactionJournalNamespace.validate(directoryURL: folder, fileManager: manager))
        // The send goes through.
        let racing = try Sora2PendingSubmissionStore(fileManager: manager, baseURL: directory)
        _ = try racing.stage(account: "cnAccount", hash: transactionHash(0xb2))
        XCTAssertEqual(try racing.all().count, 2)

        // A name of the writer that holds something the writer never
        // creates is still returned, and the folder check still rejects it.
        let foreign = folder.appendingPathComponent(".durable-\(UUID().uuidString).tmp")
        try FileManager.default.createDirectory(at: foreign, withIntermediateDirectories: false)
        XCTAssertEqual(try DurableFileWriter.contentsIgnoringLeftovers(of: folder, fileManager: manager,
            includingPropertiesForKeys: nil).map(\.lastPathComponent).sorted(),
            [foreign.lastPathComponent, "sora2-signed-v1.json"])
        XCTAssertThrowsError(try PendingTransactionJournalNamespace.validate(directoryURL: folder,
                                                                             fileManager: manager))
        XCTAssertFalse(DurableFileWriter.isLeftoverFile(at: foreign))
    }

    // MARK: 13. The Nexus and Polkamarkt journals

    func testAnUnreadableNexusOrPolkamarktJournalShowsRecoveryAndCanBeSetAside() async throws {
        let (device, first, second) = try upgradedTwoAccountDevice()
        XCTAssertEqual(try device.startup(), .ready)
        let base = device.directory
        let sora2 = try Sora2PendingSubmissionStore(baseURL: base)
        _ = try sora2.stage(account: first.address, hash: transactionHash(0xa1))
        let folder = base.appendingPathComponent("SORA/PendingTransactions")
        let root = base.appendingPathComponent("WalletSetAside")
        let coordinator = WalletLifecycleCoordinator(recoveryGate: device.isolatedGate())
        let keys = try device.keychain.bytes()
        func nexusCount() async throws -> Int { try await NexusPendingTransactionStore(baseURL: base).all().count }
        func polkamarktCount() async throws -> Int { try await PolkamarktPendingStore(baseURL: base).all().count }

        // Journals without an entry are readable.
        for name in ["nexus-v1.json", "polkamarkt-v1.json"] {
            try Data("[]".utf8).write(to: folder.appendingPathComponent(name))
        }
        let initialNexusCount = try await nexusCount()
        let initialPolkamarktCount = try await polkamarktCount()
        XCTAssertEqual(initialNexusCount, 0)
        XCTAssertEqual(initialPolkamarktCount, 0)
        XCTAssertNoThrow(try PendingTransactionRecords.requireReadable(baseURL: base))
        XCTAssertEqual(try device.startup(), .ready)

        // A row that decodes and that its own store refuses to read.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let moment = Date(timeIntervalSince1970: 1_790_000_000)
        let refusedRow = try encoder.encode([PolkamarktPendingMutation(id: UUID(), account: "", action: "claim",
            marketIds: [1], createdAt: moment, updatedAt: moment, extrinsicHash: nil, state: .preparing,
            finalizedBlock: nil, errorClass: nil)])
        let breakages: [(file: String, what: String, bytes: Data)] = [
            ("nexus-v1.json", "a Nexus journal that does not decode", Data("not a journal".utf8)),
            ("polkamarkt-v1.json", "a Polkamarkt journal that does not decode", Data("not a journal".utf8)),
            ("polkamarkt-v1.json", "a Polkamarkt row its store refuses", refusedRow),
        ]
        for (index, breakage) in breakages.enumerated() {
            let what = breakage.what
            try breakage.bytes.write(to: folder.appendingPathComponent(breakage.file))
            // That feature's store refuses every action from now on...
            if breakage.file == "nexus-v1.json" {
                do { _ = try await nexusCount(); XCTFail(what) } catch { }
                XCTAssertThrowsError(try NexusPendingTransactionStore.requireReadableJournal(
                    applicationSupportURL: base), what)
                XCTAssertNoThrow(try PolkamarktPendingStore.requireReadableJournal(applicationSupportURL: base), what)
            } else {
                do { _ = try await polkamarktCount(); XCTFail(what) } catch { }
                XCTAssertThrowsError(try PolkamarktPendingStore.requireReadableJournal(
                    applicationSupportURL: base), what)
                XCTAssertNoThrow(try NexusPendingTransactionStore.requireReadableJournal(applicationSupportURL: base), what)
            }
            // ...while the SORA2 journal itself is fine.
            XCTAssertNoThrow(try sora2.all(), what)
            XCTAssertFalse(PendingTransactionRecords.isReadable(baseURL: base), what)

            // The next launch says so on the recovery screen, with the action.
            XCTAssertEqual(try device.startup(), .recoveryRequired, what)
            XCTAssertTrue(WalletMigrationRecoveryMarker.capture(device.settings).isRetryableStartupFailure, what)
            XCTAssertEqual(WalletStartupDiagnostic.current(device.settings)?.phase, .pendingTransactions, what)
            let options = WalletRecoveryStateProbe.recovery(migrator: try device.migrator(),
                keystore: device.keychain, settings: device.settings, pendingTransactionsBaseURL: base).options
            XCTAssertTrue(options.canSetAsideTransactionRecords, what)
            XCTAssertTrue(options.canRetry, what)

            // Set aside: every journal moves, nothing is deleted.
            let moved = try XCTUnwrap(PendingTransactionRecords.setAside(applicationSupportURL: base,
                setAsideRootURL: root, lifecycleCoordinator: coordinator), what)
            XCTAssertEqual(try Data(contentsOf: moved.appendingPathComponent("PendingTransactions/\(breakage.file)")),
                           breakage.bytes, what)
            XCTAssertEqual(try InterruptedWrite.names(in: folder), [], what)
            XCTAssertEqual(try device.startup(), .ready, what)
            XCTAssertFalse(device.settings.walletMigrationRecoveryRequired, what)
            let recoveredNexusCount = try await nexusCount()
            let recoveredPolkamarktCount = try await polkamarktCount()
            XCTAssertEqual(recoveredNexusCount, 0, what)
            XCTAssertEqual(recoveredPolkamarktCount, 0, what)
            _ = try sora2.stage(account: first.address, hash: transactionHash(0xc0 + UInt8(index)))
            XCTAssertEqual(try sora2.all().count, 1, what)
        }
        XCTAssertEqual(try InterruptedWrite.names(in: root).count, breakages.count)
        XCTAssertEqual(try device.keychain.bytes(), keys)
        XCTAssertEqual(try KeySafetyStore.rows(at: device.storeURL).map(\.address), [first.address, second.address])
    }

    // MARK: 14. The recovery screen: text, buttons and the busy state agree

    func testTheRecoveryTextAboutTheRecordsFollowsTheSameFactAsTheirButton() throws {
        let recordsID = "wallet-recovery-set-aside-transaction-records"
        func options(unreadable: Bool) -> WalletRecoveryOptions {
            WalletRecoveryState.recovery(retryable: true, accountsMissingKeys: 0, accountsWithPhrase: 0,
                                         retainedPinUsable: false, transactionRecordsUnreadable: unreadable).options
        }
        func diagnostic(_ phase: WalletStartupDiagnostic.Phase) throws -> WalletStartupDiagnostic {
            let settings = InMemorySettingsManager()
            XCTAssertEqual(WalletStorageStartup.run(settings: settings, maximumAttempts: 1) {
                try WalletStartupDiagnostic.check(phase) {
                    throw PendingTransactionJournalNamespace.Failure.invalidNamespace
                }
            }, .recoveryRequired)
            return try XCTUnwrap(WalletStartupDiagnostic.current(settings))
        }
        let recordsMessage = WalletUX.text("SORA cannot read its records of transactions that were still being confirmed, so it cannot safely start a new one. Your accounts, keys and funds are not affected. You can set these records aside below. Nothing is deleted.")
        let alsoRecords = WalletUX.text("You can set aside the unreadable records of unfinished transactions below. Your wallet keys will not change.")
        let readableNow = WalletUX.text("SORA could not read its records of transactions that were still being confirmed when it last checked. Your accounts, keys and funds are not affected.")
        let retryOnly = WalletUX.text("Try again to run the wallet checks once more.")
        let restoreSteps = WalletUX.text("SORA stopped before changing anything and did not delete or replace any wallet data. Try again, restore with your recovery phrase or Google Drive backup, or contact SORA support with the app version shown below. Never share your recovery phrase.")
        // The two sentences that say "you can set these records aside below".
        func promisesTheButton(_ body: String) -> Bool {
            body.contains(recordsMessage) || body.contains(alsoRecords)
        }

        // (a) The startup check failed for the records, and they can be read
        // now (the read error was transient): no button, and no sentence
        // that promises one.
        let transient = WalletRecoveryViewController(reason: "fixture", diagnostic: try diagnostic(.pendingTransactions),
                                                     onRetry: {}, onSetAside: {})
        transient.loadViewIfNeeded()
        transient.apply(options(unreadable: false))
        XCTAssertTrue(try button(recordsID, in: transient).isHidden)
        XCTAssertTrue(try bodyText(of: transient).contains(readableNow))
        XCTAssertTrue(try bodyText(of: transient).contains(retryOnly))
        XCTAssertFalse(promisesTheButton(try bodyText(of: transient)))
        XCTAssertFalse(try button("wallet-recovery-retry", in: transient).isHidden)
        // The records are unreadable after all: the button and its text.
        transient.apply(options(unreadable: true))
        XCTAssertFalse(try button(recordsID, in: transient).isHidden)
        XCTAssertTrue(try bodyText(of: transient).hasPrefix(recordsMessage))
        XCTAssertFalse(try bodyText(of: transient).contains(restoreSteps))

        // (b) Another check failed first and the records cannot be read
        // either: the button is explained.
        let other = WalletRecoveryViewController(reason: "fixture", diagnostic: try diagnostic(.networkSnapshot),
                                                 onRetry: {}, onSetAside: {})
        other.loadViewIfNeeded()
        XCTAssertFalse(promisesTheButton(try bodyText(of: other)))
        other.apply(options(unreadable: true))
        XCTAssertFalse(try button(recordsID, in: other).isHidden)
        XCTAssertTrue(try bodyText(of: other).contains(alsoRecords))
        XCTAssertFalse(try bodyText(of: other).contains(restoreSteps), "No unavailable restore action is promised")
        other.apply(options(unreadable: false))
        XCTAssertTrue(try button(recordsID, in: other).isHidden)
        XCTAssertFalse(promisesTheButton(try bodyText(of: other)))

        // (c) A recovery screen without "Try again" shows neither.
        let passive = WalletRecoveryViewController(reason: "fixture")
        passive.loadViewIfNeeded()
        passive.apply(options(unreadable: true))
        XCTAssertTrue(try button(recordsID, in: passive).isHidden)
        XCTAssertFalse(promisesTheButton(try bodyText(of: passive)))

        for key in [
            "SORA also cannot read its records of transactions that were still being confirmed. You can set these records aside below. Nothing is deleted.",
            "SORA could not read its records of transactions that were still being confirmed when it last checked. Your accounts, keys and funds are not affected.",
            "Try again. If this screen appears again, contact SORA support with the app version shown below. Never share your recovery phrase.",
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

    func testWhileTheRecordsAreSetAsideNoOtherRecoveryActionCanStart() throws {
        let device = try Installation()
        let store = try Sora2PendingSubmissionStore(baseURL: device.directory)
        _ = try store.stage(account: "cnAccount", hash: transactionHash(0xa1))
        let folder = device.directory.appendingPathComponent("SORA/PendingTransactions")
        try Data("a later version's journal".utf8).write(to: folder.appendingPathComponent("sora2-signed-v2.json"))
        let root = device.directory.appendingPathComponent("WalletSetAside")

        var retries = 0
        var folderExistedAtRetry: Bool?
        let controller = WalletRecoveryViewController(reason: "fixture", onRetry: {
            retries += 1
            folderExistedAtRetry = FileManager.default.fileExists(
                atPath: folder.appendingPathComponent("sora2-signed-v2.json").path)
        }, onSetAside: {})
        controller.loadViewIfNeeded()
        var options = WalletRecoveryOptions()
        options.canRetry = true
        options.canExport = true
        options.canSetUpDeviceAgain = true
        options.canSetAsideTransactionRecords = true
        controller.apply(options)
        let retry = try button("wallet-recovery-retry", in: controller)
        let records = try button("wallet-recovery-set-aside-transaction-records", in: controller)
        let setUpAgain = try button("wallet-recovery-set-up-again", in: controller)
        let export = try button(RetainedMigrationEvidenceHarness.recoveryExportAccessibilityIdentifier, in: controller)
        for control in [retry, records, setUpAgain, export] { XCTAssertTrue(control.isEnabled) }

        // The move is held at its first step.
        let started = DispatchSemaphore(value: 0)
        let proceed = DispatchSemaphore(value: 0)
        controller.transactionRecordsPaths = {
            started.signal()
            proceed.wait()
            return WalletLocalStateSetAside.Paths(storeURL: device.storeURL,
                applicationSupportURL: device.directory, setAsideRootURL: root)
        }
        controller.setAsideTransactionRecords()
        XCTAssertEqual(started.wait(timeout: .now() + 10), .success)
        for control in [retry, records, setUpAgain, export] { XCTAssertFalse(control.isEnabled) }
        // "Try again" while the folder is still in place does nothing, and a
        // second set-aside does not start.
        retry.sendActions(for: .touchUpInside)
        controller.setAsideTransactionRecords()
        XCTAssertEqual(retries, 0)

        proceed.signal()
        let deadline = Date().addingTimeInterval(10)
        while retries == 0, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        // The startup checks run once, after the folder has moved.
        XCTAssertEqual(retries, 1)
        XCTAssertEqual(folderExistedAtRetry, false)
        XCTAssertEqual(try InterruptedWrite.names(in: root).count, 1)
        XCTAssertEqual(try InterruptedWrite.names(in: folder), [])
        XCTAssertFalse(retry.isEnabled)
        XCTAssertFalse(records.isEnabled)
    }

    // MARK: 15. "Set up this iPhone again": a finished folder is never reused

    func testAFinishedSetAsideFolderIsNeverTakenForAnUnfinishedOne() throws {
        func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try KeySafetyStore.write([account], to: device.storeURL)
        device.settings.set(value: account, for: SettingsKey.selectedAccount.rawValue)
        XCTAssertEqual(try device.startup(), .ready)
        device.settings.setWalletMigrationRecovery(reason: "Some other integrity check")
        let marker = WalletMigrationRecoveryMarker.capture(device.settings)
        let keys = try device.keychain.bytes()
        let firstStore = try Data(contentsOf: device.storeURL)
        let root = device.directory.appendingPathComponent("WalletSetAside")
        let paths = WalletLocalStateSetAside.Paths(storeURL: device.storeURL,
            applicationSupportURL: device.directory, setAsideRootURL: root)
        func coordinator() -> WalletLifecycleCoordinator {
            WalletLifecycleCoordinator(recoveryGate: device.isolatedGate())
        }

        // 1. Everything moves and the wallet settings go; then the recovery
        // marker turns out to have changed, so it is not cleared. The folder
        // is complete all the same and must not stay marked as unfinished.
        XCTAssertThrowsError(try WalletLocalStateSetAside.setAside(settings: device.settings, expectedMarker: marker,
            paths: paths, lifecycleCoordinator: coordinator(), afterMoves: {
                device.settings.setWalletMigrationRecovery(reason: "Another integrity check")
            })) { error in
            guard case WalletLocalStateSetAside.Failure.markerChanged = error else { return XCTFail("\(error)") }
        }
        let folders = try InterruptedWrite.names(in: root)
        XCTAssertEqual(folders.count, 1)
        let firstFolder = root.appendingPathComponent(folders[0])
        XCTAssertFalse(exists(firstFolder.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName)))
        XCTAssertEqual(try Data(contentsOf: firstFolder.appendingPathComponent("CoreData/UserDataModel.sqlite")),
                       firstStore)
        XCTAssertFalse(exists(device.storeURL))
        XCTAssertFalse(device.settings.hasRetainedWalletSettings())
        let firstContents = try InterruptedWrite.names(in: firstFolder)

        // 2. Later another wallet lives on this iPhone, and "Set up this
        // iPhone again" is chosen for it. It gets a folder of its own.
        let other = try HistoricalWriter.phraseImport(try phrase(entropy: 0x31, bytes: 16), username: "Later",
                                                      keystore: device.keychain.base)
        try KeySafetyStore.write([other], to: device.storeURL)
        let laterStore = try Data(contentsOf: device.storeURL)
        XCTAssertNotEqual(laterStore, firstStore)
        let laterMarker = WalletMigrationRecoveryMarker.capture(device.settings)
        XCTAssertTrue(laterMarker.required)
        let second = try WalletLocalStateSetAside.setAside(settings: device.settings, expectedMarker: laterMarker,
            paths: paths, lifecycleCoordinator: coordinator())
        XCTAssertEqual(try InterruptedWrite.names(in: root).count, 2)
        XCTAssertNotEqual(second.lastPathComponent, firstFolder.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: second.appendingPathComponent("CoreData/UserDataModel.sqlite")), laterStore)
        XCTAssertFalse(exists(second.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName)))
        // The first wallet's folder is as it was.
        XCTAssertEqual(try InterruptedWrite.names(in: firstFolder), firstContents)
        XCTAssertEqual(try Data(contentsOf: firstFolder.appendingPathComponent("CoreData/UserDataModel.sqlite")),
                       firstStore)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(try device.keychain.bytes()[KeystoreTag.secretKeyTagForAddress(account.address)],
                       keys[KeystoreTag.secretKeyTagForAddress(account.address)])
        XCTAssertFalse(device.keychain.changedExistingItems)

        // 3. A folder that is marked unfinished and already holds a database
        // (a build before this fix left the mark on a finished folder): a
        // later wallet's database and its `-wal` and `-shm` files go into
        // one subfolder together, under their own names.
        let third = try Installation()
        let thirdAccount = try HistoricalWriter.phraseImport(phrase12, keystore: third.keychain.base)
        try KeySafetyStore.write([thirdAccount], to: third.storeURL)
        XCTAssertEqual(try third.startup(), .ready)
        try Data("write-ahead log".utf8).write(to: URL(fileURLWithPath: third.storeURL.path + "-wal"))
        try Data("shared memory".utf8).write(to: URL(fileURLWithPath: third.storeURL.path + "-shm"))
        let thirdStore = try Data(contentsOf: third.storeURL)
        third.settings.setWalletMigrationRecovery(reason: "Some other integrity check")
        let thirdRoot = third.directory.appendingPathComponent("WalletSetAside")
        let marked = thirdRoot.appendingPathComponent("1700000000-\(UUID().uuidString)")
        for name in ["CoreData/WalletMigrationSafety", "WalletNetworks", "WalletAccountCommits"] {
            try FileManager.default.createDirectory(at: marked.appendingPathComponent(name),
                                                    withIntermediateDirectories: true)
        }
        let earlierContents = try InterruptedWrite.names(in: marked)
        try Data("an earlier wallet's database".utf8)
            .write(to: marked.appendingPathComponent("CoreData/UserDataModel.sqlite"))
        try Data("marked".utf8).write(to: marked.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName))
        let continued = try WalletLocalStateSetAside.setAside(settings: third.settings,
            expectedMarker: WalletMigrationRecoveryMarker.capture(third.settings),
            paths: WalletLocalStateSetAside.Paths(storeURL: third.storeURL, applicationSupportURL: third.directory,
                                                  setAsideRootURL: thirdRoot),
            lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: third.isolatedGate()))
        XCTAssertEqual(continued.lastPathComponent, marked.lastPathComponent)
        XCTAssertFalse(exists(marked.appendingPathComponent(WalletLocalStateSetAside.incompleteMarkerName)))
        // The earlier database is untouched and has no new neighbour.
        XCTAssertEqual(try Data(contentsOf: marked.appendingPathComponent("CoreData/UserDataModel.sqlite")),
                       Data("an earlier wallet's database".utf8))
        XCTAssertEqual(try InterruptedWrite.names(in: marked.appendingPathComponent("CoreData")).filter {
            $0.hasPrefix("UserDataModel.sqlite")
        }, ["UserDataModel.sqlite"])
        let later = try InterruptedWrite.names(in: marked).filter { $0.hasPrefix("later-") }
        XCTAssertEqual(later.count, 1)
        let laterFolder = marked.appendingPathComponent(try XCTUnwrap(later.first))
        XCTAssertEqual(try Data(contentsOf: laterFolder.appendingPathComponent("CoreData/UserDataModel.sqlite")),
                       thirdStore)
        XCTAssertEqual(try Data(contentsOf: laterFolder.appendingPathComponent("CoreData/UserDataModel.sqlite-wal")),
                       Data("write-ahead log".utf8))
        XCTAssertEqual(try Data(contentsOf: laterFolder.appendingPathComponent("CoreData/UserDataModel.sqlite-shm")),
                       Data("shared memory".utf8))
        XCTAssertTrue(exists(laterFolder.appendingPathComponent("WalletNetworks/active.json")))
        XCTAssertEqual(try InterruptedWrite.names(in: laterFolder), ["CoreData", "WalletAccountCommits", "WalletNetworks"])
        XCTAssertEqual(try InterruptedWrite.names(in: laterFolder.appendingPathComponent("CoreData")),
                       ["UserDataModel.sqlite", "UserDataModel.sqlite-shm", "UserDataModel.sqlite-wal",
                        "WalletMigrationSafety"])
        // Beside the earlier wallet's items: the subfolder and a second
        // copy of the settings, nothing under a made-up name.
        XCTAssertEqual(try InterruptedWrite.names(in: marked).filter {
            !$0.hasPrefix("later-") && !$0.hasPrefix("wallet-settings-") && $0 != "wallet-settings.plist"
        }, earlierContents.filter { $0 != WalletLocalStateSetAside.incompleteMarkerName })
        XCTAssertEqual(try InterruptedWrite.names(in: marked.appendingPathComponent("WalletNetworks")), [])
        XCTAssertFalse(exists(third.storeURL))
        XCTAssertFalse(third.settings.walletMigrationRecoveryRequired)
        XCTAssertTrue(third.keychain.added.isEmpty && !third.keychain.changedExistingItems)
    }

    // MARK: 16. The storage checks the app runs at launch

    func testTheStorageChecksOfALaunchSweepHelperFilesBeforeAnythingElse() throws {
        for sweeps in [true, false] {
            let label = "sweeps: \(sweeps)"
            let (device, first, _) = try upgradedTwoAccountDevice()
            XCTAssertEqual(try device.startup(), .ready, label)
            _ = try Sora2PendingSubmissionStore(baseURL: device.directory)
                .stage(account: first.address, hash: transactionHash(0xa1))
            let sora = device.directory.appendingPathComponent("SORA")
            let attempt = try XCTUnwrap(try FileManager.default.contentsOfDirectory(
                at: device.directory.appendingPathComponent("WalletMigrationSafety"),
                includingPropertiesForKeys: nil).first)
            for folder in [sora.appendingPathComponent("WalletNetworks"), sora.appendingPathComponent("WalletAccountCommits"),
                           sora.appendingPathComponent("PendingTransactions"), attempt,
                           attempt.appendingPathComponent("legacy-store"), attempt.appendingPathComponent("staging")] {
                try InterruptedWrite.plantHelperFiles(in: folder)
            }
            // A marker the launch does not retry: the checks stop before the
            // database, the snapshot and the transaction records are read.
            device.settings.setWalletMigrationRecovery(reason: "Some other integrity check")
            let gate = device.gate()
            let checks = WalletStorageStartup.runChecks(settings: device.settings, keystore: device.keychain,
                storeURL: device.storeURL, modelDirectory: UserStorageParams.modelDirectory,
                applicationSupportURL: device.directory,
                lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate), recoveryGate: gate,
                databaseMigrator: try device.migrator(gate: gate), sweepsHelperFiles: sweeps, retryDelay: { _ in })
            XCTAssertEqual(checks, WalletStorageStartup.Checks(outcome: .recoveryRequired,
                                                               deferredForLegacyUpgrade: false), label)
            if sweeps {
                // The sweep comes first, so it ran although the checks stopped.
                XCTAssertEqual(InterruptedWrite.helperFiles(under: device.directory), [], label)
            } else {
                XCTAssertFalse(InterruptedWrite.helperFiles(under: device.directory).isEmpty, label)
            }
        }
    }
}

private final class PINMutationFaultKeychain: KeystoreProtocol {
    let base: KeystoreProtocol
    var failureIndex: Int?
    var mutations = 0
    init(_ base: KeystoreProtocol) { self.base = base }
    private func checkpoint() throws {
        mutations += 1
        if mutations == failureIndex { throw WalletOwnerPIN.Failure.persistenceFailed }
    }
    func addKey(_ key: Data, with identifier: String) throws { try checkpoint(); try base.addKey(key, with: identifier) }
    func updateKey(_ key: Data, with identifier: String) throws { try checkpoint(); try base.updateKey(key, with: identifier) }
    func deleteKey(for identifier: String) throws { try checkpoint(); try base.deleteKey(for: identifier) }
    func fetchKey(for identifier: String) throws -> Data { try base.fetchKey(for: identifier) }
    func checkKey(for identifier: String) throws -> Bool { try base.checkKey(for: identifier) }
    func allKeyIdentifiers() throws -> [String] { try base.allKeyIdentifiers() }
}

/// Own namespace only, using the production kSecClassKey / ThisDeviceOnly implementation.
private final class PINRealKeychainNamespace: KeystoreProtocol {
    let base = Keychain()
    let prefix = "pin-audit-\(UUID().uuidString)-"
    func addKey(_ key: Data, with identifier: String) throws { try base.addKey(key, with: prefix + identifier) }
    func updateKey(_ key: Data, with identifier: String) throws { try base.updateKey(key, with: prefix + identifier) }
    func deleteKey(for identifier: String) throws { try base.deleteKey(for: prefix + identifier) }
    func fetchKey(for identifier: String) throws -> Data { try base.fetchKey(for: prefix + identifier) }
    func checkKey(for identifier: String) throws -> Bool { try base.checkKey(for: prefix + identifier) }
    func allKeyIdentifiers() throws -> [String] {
        try base.allKeyIdentifiers().filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }
    func cleanUp() { for tag in (try? allKeyIdentifiers()) ?? [] { try? deleteKey(for: tag) } }
}

extension WalletKeySafetyTests {
    func testOwnerPINRotationRecoversEveryInterruptedWriteBeforeAuthentication() throws {
        for interruption in 1...5 {
            let base = InMemoryKeychain()
            let keys = PINMutationFaultKeychain(base)
            let settings = InMemorySettingsManager()
            let gate = WalletRecoveryCapabilityGate(settings: settings,
                unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
            let first = try HistoricalWriter.phraseImport(phrase12, keystore: base)
            let second = try HistoricalWriter.phraseImport(phrase(entropy: 0x72, bytes: 16), keystore: base)
            let accounts = [first, second]
            let original = try accounts.map { try base.fetchSecretKeyForAddress($0.address) }
            let service = WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate)
            WalletPendingPinSetup.begin(settings)
            for account in accounts { try service.prepareInitialSetup(account: account, operationID: UUID()) }
            try service.setInitialPIN("111111", accounts: accounts)
            let grant = try service.authenticateCurrent("111111", accounts: accounts)
            keys.mutations = 0; keys.failureIndex = interruption
            XCTAssertThrowsError(try service.rotate(to: "222222", authorization: grant, accounts: accounts))
            keys.failureIndex = nil
            let restarted = WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate)
            try restarted.recoverRotation()
            let expectedPIN = interruption == 1 ? "111111" : "222222"
            XCTAssertEqual(try base.fetchKey(for: KeystoreTag.pincode.rawValue), Data(expectedPIN.utf8))
            XCTAssertEqual(try restarted.verifyRetained(expectedPIN, addresses: Set(accounts.map(\.address))),
                           Set(accounts.map(\.address)))
            XCTAssertFalse(try base.checkKey(for: WalletOwnerPIN.rotationTag))
            XCTAssertEqual(try accounts.map { try base.fetchSecretKeyForAddress($0.address) }, original)
            // The same UI submission can retry after its failed write/readback.
            XCTAssertNoThrow(try service.rotate(to: "222222", authorization: grant, accounts: accounts))
            XCTAssertEqual(try base.fetchKey(for: KeystoreTag.pincode.rawValue), Data("222222".utf8))
        }
    }

    func testOwnerPINThrottleSurvivesReinstallClockChangesAndAnotherOwnersSuccess() throws {
        let keys = InMemoryKeychain()
        let first = try HistoricalWriter.phraseImport(phrase12, keystore: keys)
        let second = try HistoricalWriter.phraseImport(phrase(entropy: 0x73, bytes: 16), keystore: keys)
        try saveOwnerBindingFixture("111111", accounts: [first], keystore: keys)
        try saveOwnerBindingFixture("222222", accounts: [second], keystore: keys)
        let settings = InMemorySettingsManager()
        var now = Date(timeIntervalSince1970: 1_000), uptime: TimeInterval = 1000, boot = "boot-a"
        func service() -> WalletOwnerPIN {
            WalletOwnerPIN(keystore: keys, settings: InMemorySettingsManager(), now: { now },
                           uptime: { uptime }, boot: { boot })
        }
        for _ in 0..<3 {
            // The attacker's successful PIN cannot clear the victim's failed attempts.
            XCTAssertEqual(try service().verifyRetained("222222", addresses: [first.address, second.address]), [second.address])
        }
        let tag = first.address + WalletOwnerPIN.throttleSuffix
        XCTAssertEqual(try JSONDecoder().decode(WalletOwnerPIN.Throttle.self, from: keys.fetchKey(for: tag)).failures, 3)
        settings.removeValue(for: "ignored-reinstalled-defaults")
        now.addTimeInterval(30 * 86400)
        XCTAssertThrowsError(try service().verifyRetained("111111", addresses: [first.address]))
        uptime = 1030
        XCTAssertThrowsError(try service().verifyRetained("111111", addresses: [first.address]))
        boot = "boot-b"; uptime = 1
        XCTAssertThrowsError(try service().verifyRetained("111111", addresses: [first.address]))
        uptime = 62
        XCTAssertThrowsError(try service().verifyRetained("000000", addresses: [first.address]))
        XCTAssertEqual(try JSONDecoder().decode(WalletOwnerPIN.Throttle.self, from: keys.fetchKey(for: tag)).wait, 300)
        uptime = 363
        XCTAssertEqual(try service().verifyRetained("111111", addresses: [first.address]), [first.address])
        XCTAssertFalse(try keys.checkKey(for: tag))
    }

    func testDowngradedAppPINReconcilesOnlyAfterManualProofAndOnlyExistingRows() throws {
        let keys = InMemoryKeychain(), settings = InMemorySettingsManager()
        let gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        let first = try HistoricalWriter.phraseImport(phrase12, keystore: keys)
        let retained = try HistoricalWriter.phraseImport(phrase(entropy: 0x74, bytes: 16), keystore: keys)
        try saveOwnerBindingFixture("111111", accounts: [first, retained], keystore: keys)
        // The released writer updates pincode only, leaving owner bindings unchanged.
        try keys.saveKey(Data("222222".utf8), with: KeystoreTag.pincode.rawValue)
        let before = try keys.fetchKey(for: first.address + WalletOwnerPIN.bindingSuffix)
        let service = WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate)
        try service.recoverRotation()
        XCTAssertEqual(try keys.fetchKey(for: first.address + WalletOwnerPIN.bindingSuffix), before)
        _ = try service.authenticateCurrent("222222", accounts: [first])
        XCTAssertEqual(try service.verifyRetained("222222", addresses: [first.address, retained.address]), [first.address])
        XCTAssertEqual(try service.verifyRetained("111111", addresses: [first.address, retained.address]), [retained.address])
    }

    func testMixedPINRestorationPublishesBindingOnlyWithCommittedRow() throws {
        let keys = InMemoryKeychain(), settings = InMemorySettingsManager()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: keys)
        try saveOwnerBindingFixture("111111", accounts: [account], keystore: keys)
        try keys.saveKey(Data("222222".utf8), with: KeystoreTag.pincode.rawValue)
        let original = try keys.fetchKey(for: account.address + WalletOwnerPIN.bindingSuffix)
        let service = WalletOwnerPIN(keystore: keys, settings: settings)
        XCTAssertEqual(try service.verifyRetained("111111", addresses: [account.address]), [account.address])
        try service.prepareRebinding(address: account.address, to: "222222")
        XCTAssertEqual(try keys.fetchKey(for: account.address + WalletOwnerPIN.bindingSuffix), original)
        XCTAssertThrowsError(try service.verifyRetained("111111", addresses: [account.address]))
        try service.settleRebindings(currentAddresses: [])
        XCTAssertEqual(try keys.fetchKey(for: account.address + WalletOwnerPIN.bindingSuffix), original)
        try service.prepareRebinding(address: account.address, to: "222222")
        try service.settleRebindings(currentAddresses: [account.address])
        XCTAssertEqual(try service.verifyRetained("222222", addresses: [account.address]), [account.address])
        XCTAssertThrowsError(try service.verifyRetained("111111", addresses: [account.address]))
    }

    func testTwoReinstallBypassFailsOnProductionSimulatorKeychain() throws {
        let keys = PINRealKeychainNamespace()
        defer { keys.cleanUp() }
        let settings = PINTestDefaults()
        defer { settings.removeAll() }
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storeURL = container.appendingPathComponent("UserDataModel.sqlite")
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: container) }
        func simulateUninstall() throws {
            settings.removeAll()
            try FileManager.default.removeItem(at: container)
            try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
            XCTAssertTrue(try KeySafetyStore.rows(at: storeURL).isEmpty)
            XCTAssertTrue(settings.allKeys().isEmpty)
        }
        let gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        let victim = try HistoricalWriter.phraseImport(phrase12, keystore: keys)
        try KeySafetyStore.write([victim], to: storeURL)
        WalletPendingPinSetup.begin(settings)
        let originalOwner = WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate)
        try originalOwner.prepareInitialSetup(account: victim, operationID: UUID())
        try originalOwner.setInitialPIN("111111", accounts: KeySafetyStore.rows(at: storeURL))
        let before = try keys.fetchSecretKeyForAddress(victim.address)
        // Account database and preferences of the first install do not survive.
        try simulateUninstall()
        let reinstallSettings = settings
        let attacker = try HistoricalWriter.phraseImport(phrase(entropy: 0x75, bytes: 16), keystore: keys)
        try KeySafetyStore.write([attacker], to: storeURL)
        WalletPendingPinSetup.begin(reinstallSettings)
        let newOwner = WalletOwnerPIN(keystore: keys, settings: reinstallSettings, recoveryGate: gate)
        try newOwner.prepareInitialSetup(account: attacker, operationID: UUID())
        try newOwner.setInitialPIN("222222", accounts: KeySafetyStore.rows(at: storeURL))
        try simulateUninstall()
        let secondReinstall = WalletOwnerPIN(keystore: keys, settings: settings, recoveryGate: gate)
        XCTAssertEqual(try secondReinstall.verifyRetained("222222", addresses: [victim.address, attacker.address]), [attacker.address])
        XCTAssertEqual(try secondReinstall.verifyRetained("111111", addresses: [victim.address, attacker.address]), [victim.address])
        XCTAssertEqual(try keys.fetchSecretKeyForAddress(victim.address), before)
        XCTAssertEqual(Keychain.accessibility, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }
}

extension WalletKeySafetyTests {
    func testAbsentDirectKeyUsesEachProvenBackupDespiteAStaleOrUnreadableSibling() throws {
        for crypto in [CryptoType.sr25519, .ed25519, .ecdsa] {
            for goodSource in ["phrase", "seed"] {
                for unreadable in [false, true] {
                    let device = try Installation()
                    let account = try HistoricalWriter.phraseImport(phrase12, path: "//1", cryptoType: crypto,
                                                                   keystore: device.keychain.base)
                    try device.keychain.base.deleteKey(for: KeystoreTag.secretKeyTagForAddress(account.address))
                    let suffix = goodSource == "phrase" ? "-seed" : "-entropy"
                    if !unreadable {
                        try device.keychain.base.updateKey(Data(repeating: 0x55, count: goodSource == "phrase" ? 32 : 16),
                                                          with: account.address + suffix)
                    }
                    let keys: KeystoreProtocol = unreadable
                        ? AuxiliaryReadFailureKeychain(device.keychain, blockedSuffixes: [suffix]) : device.keychain
                    let before = try device.keychain.bytes()
                    let gate = device.isolatedGate()
                    XCTAssertEqual(try WalletAccountKeyAvailability.status(for: account, keystore: keys,
                        settings: device.settings, activeSnapshot: nil, recoveryGate: gate), .available)
                    let secret = try XCTUnwrap(LegacySoraSecretResolver.resolve(account: account, keystore: keys, recoveryGate: gate))
                    XCTAssertNoThrow(try LegacySoraIdentityValidator.validateSigningSecret(address: account.address,
                        publicKey: account.publicKeyData, cryptoType: crypto, networkType: account.networkType,
                        secret: secret, recoveryGate: gate))
                    try KeySafetyStore.write([account], to: device.storeURL, version: .version1)
                    let migrator = UserStorageMigrator(targetVersion: .version2, storeURL: device.storeURL,
                        modelDirectory: UserStorageParams.modelDirectory, keystore: keys, settings: device.settings,
                        fileManager: .default, recoveryGate: gate, availableCapacity: { _ in Int64.max },
                        loadWalletNetworkSnapshot: { nil })
                    XCTAssertNoThrow(try migrator.performMigration(), "\(crypto)/\(goodSource)/\(unreadable)")
                    XCTAssertEqual(try device.keychain.bytes(), before)
                }
            }
        }
    }

    func testRecoveryPhraseRevealIncludesProvenPathAndOnlyMatchedWallets() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, path: "/soft//hard///password",
                                                        keystore: device.keychain.base)
        let other = try HistoricalWriter.phraseImport(phrase(entropy: 0x76, bytes: 16), keystore: device.keychain.base)
        try saveOwnerBindingFixture("111111", accounts: [account], keystore: device.keychain.base)
        try saveOwnerBindingFixture("222222", accounts: [other], keystore: device.keychain.base)
        let entries = try WalletRecoveryPhraseReveal.reveal(pin: "111111", accounts: [account, other],
            keystore: device.keychain, settings: device.settings, recoveryGate: device.isolatedGate())
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entry.words.joined(separator: " "), phrase12)
        XCTAssertEqual(entry.derivationPath, "/soft//hard///password")
        let restored = try HistoricalWriter.phraseImport(entry.words.joined(separator: " "),
            path: entry.derivationPath ?? "", keystore: InMemoryKeychain())
        XCTAssertEqual(restored.address, account.address)
    }
}

private final class PINTestDefaults: SettingsManagerProtocol {
    private let name = "wallet-pin-tests-" + UUID().uuidString
    private lazy var defaults = UserDefaults(suiteName: name)!
    func set(value: Bool, for key: String) { set(anyValue: value, for: key) }
    func set(value: Int, for key: String) { set(anyValue: value, for: key) }
    func set(value: Double, for key: String) { set(anyValue: value, for: key) }
    func set(value: String, for key: String) { set(anyValue: value, for: key) }
    func set(value: Data, for key: String) { set(anyValue: value, for: key) }
    func set(anyValue: Any, for key: String) { defaults.set(anyValue, forKey: key); defaults.synchronize() }
    func bool(for key: String) -> Bool? { defaults.object(forKey: key) == nil ? nil : defaults.bool(forKey: key) }
    func integer(for key: String) -> Int? { defaults.object(forKey: key) == nil ? nil : defaults.integer(forKey: key) }
    func double(for key: String) -> Double? { defaults.object(forKey: key) == nil ? nil : defaults.double(forKey: key) }
    func string(for key: String) -> String? { defaults.string(forKey: key) }
    func data(for key: String) -> Data? { defaults.data(forKey: key) }
    func anyValue(for key: String) -> Any? { defaults.object(forKey: key) }
    func allKeys() -> [String] { Array((defaults.persistentDomain(forName: name) ?? [:]).keys) }
    func removeValue(for key: String) { defaults.removeObject(forKey: key); defaults.synchronize() }
    func removeAll() { defaults.removePersistentDomain(forName: name); defaults.synchronize() }
}

// MARK: - States left by the modernize line's earlier builds

/// The modernize line shipped internal TestFlight builds 2026101302 and
/// 2026101303 before it had per-wallet PIN ownership, and the interim
/// recovery-exits build renamed Keychain copies and moved files aside. These
/// tests pin what this line does with the states those builds leave behind
/// after the app is deleted and installed again.
final class WalletRecoveryConvergenceTests: XCTestCase {
    private func files(under folder: URL) throws -> [String: Data] {
        let paths = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey])?
            .compactMap { $0 as? URL } ?? []
        var result: [String: Data] = [:]
        for url in paths where (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
            result[String(url.path.dropFirst(folder.path.count))] = try Data(contentsOf: url)
        }
        return result
    }

    /// 2026101302/03 wrote the App Store 3.8.6 item set and the app PIN, and no
    /// `-ownerPin` binding. After a reinstall the wallet is found, but only its
    /// phrase or Drive backup restores it; the PIN item alone proves nothing.
    func testAWalletWithoutAnOwnerBindingNeedsItsPhraseAfterAReinstall() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)
        let retained = try device.keychain.bytes()

        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
        let state = WalletRecoveryStateProbe.welcomeBack(keystore: device.keychain, settings: device.settings)
        XCTAssertEqual(state, .welcomeBack(adoptableWallets: 0, walletsWithPhrase: 0, retainedPinUsable: false))
        XCTAssertTrue(state.options.canRestoreFromPhrase)
        XCTAssertTrue(state.options.canRestoreFromDrive)
        XCTAssertTrue(state.options.canSetUpDeviceAgain)
        XCTAssertFalse(state.options.canRestoreExistingKeys)
        XCTAssertThrowsError(try WalletRetainedPinGate.verify("123456", keystore: device.keychain,
                                                             settings: device.settings)) {
            XCTAssertEqual($0 as? WalletRetainedPinGate.Failure, .noRetainedPin)
        }
        XCTAssertEqual(try device.keychain.bytes(), retained)

        // The phrase restores it in place: every retained item is adopted.
        let imported = try device.importPhrase(phrase12, into: try device.selectedWalletSettings())
        XCTAssertEqual(imported.address, account.address)
        XCTAssertFalse(device.keychain.changedExistingItems)
        for (tag, bytes) in retained { XCTAssertEqual(try device.keychain.fetchKey(for: tag), bytes, tag) }
    }

    /// The reporting iPhone after its reinstall: Keychain items, and in the new
    /// install's settings only the marker and diagnostic 2026101303 latched
    /// (database_migration / missing_wallet_store).
    func testTheMarkerAndDiagnosticLatchedBy2026101303LeadToWelcomeBack() throws {
        let device = try Installation()
        try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)
        device.settings.setWalletMigrationRecovery(reason: UserStorageMigrationError
            .privacySafeRecoveryDescription(for: UserStorageMigrationError.missingWalletStore))
        WalletStartupDiagnostic.record(UserStorageMigrationError.missingWalletStore, phase: .databaseMigration,
                                       settings: device.settings)
        XCTAssertNotNil(WalletStartupDiagnostic.current(device.settings))
        let retained = try device.keychain.bytes()

        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
        XCTAssertEqual(try device.keychain.bytes(), retained)
    }

    /// The interim recovery-exits build kept verified copies of live items as
    /// `retired.<archive>.<tag>.retired`, PIN attempts as `pincodeAttempts`,
    /// and moved files to Application Support/SORA/WalletRecoveryArchive.
    /// None of them is read as a wallet, and none is changed or removed.
    func testInterimRecoveryBuildLeftoversStayAndChangeNoRouting() throws {
        let device = try Installation()
        let account = try HistoricalWriter.phraseImport(phrase12, keystore: device.keychain.base)
        try device.keychain.base.addKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)
        let archive = "20261024T061500Z-0a1b2c3d"
        for tag in try device.keychain.base.allKeyIdentifiers() {
            try device.keychain.base.addKey(try device.keychain.base.fetchKey(for: tag),
                                            with: "retired.\(archive).\(tag).retired")
        }
        try device.keychain.base.addKey(Data(#"{"failures":2}"#.utf8), with: "pincodeAttempts")
        let archived = device.directory.appendingPathComponent("SORA/WalletRecoveryArchive/\(archive)", isDirectory: true)
        try FileManager.default.createDirectory(at: archived.appendingPathComponent("CoreData", isDirectory: true),
                                                withIntermediateDirectories: true)
        try Data("archived database".utf8).write(to: archived.appendingPathComponent("CoreData/UserDataModel.sqlite"))
        try Data(#"{"archiveId":"\#(archive)"}"#.utf8).write(to: archived.appendingPathComponent("manifest.json"))
        let retained = try device.keychain.bytes()
        let archivedFiles = try files(under: archived)

        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
        let inventory = try RetainedKeychainWalletDiscovery.inventory(keystore: device.keychain,
                                                                      recoveryGate: device.isolatedGate())
        XCTAssertEqual(inventory.adoptable.map(\.address), [account.address])
        XCTAssertEqual(inventory.unprovableAddressCount, 0)
        XCTAssertEqual(try device.keychain.bytes(), retained)
        XCTAssertEqual(try files(under: archived), archivedFiles)
    }

    /// A wallet set up on this line (import, then PIN setup) is bound to its
    /// PIN. After a delete and reinstall Welcome back offers it, only that PIN
    /// restores it, and the restored wallet keeps that PIN and its keys.
    func testAWalletSetUpOnThisLineIsRestoredAfterAReinstallOnlyWithItsOwnPIN() throws {
        let first = try Installation()
        let account = try first.importPhrase(phrase12, into: try first.selectedWalletSettings())
        try WalletOwnerPIN(keystore: first.keychain, settings: first.settings, recoveryGate: first.isolatedGate())
            .setInitialPIN("246810", accounts: [account])
        XCTAssertEqual(try WalletOwnerPIN.boundAddresses(keystore: first.keychain), [account.address])

        // Delete and install again: only the Keychain survives.
        let device = try Installation()
        for (tag, bytes) in try first.keychain.bytes() { try device.keychain.base.addKey(bytes, with: tag) }
        let before = try device.keychain.bytes()
        XCTAssertEqual(try device.startup(), .ready)
        XCTAssertFalse(device.settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(try device.rootDecision(selected: nil), [.welcomeBack])
        let state = WalletRecoveryStateProbe.welcomeBack(keystore: device.keychain, settings: device.settings)
        XCTAssertEqual(state, .welcomeBack(adoptableWallets: 1, walletsWithPhrase: 1, retainedPinUsable: true))
        XCTAssertTrue(state.options.canRestoreExistingKeys)

        // As WalletRetainedWalletRestoreFlow does for Welcome back.
        let owner = WalletOwnerPIN(keystore: device.keychain, settings: device.settings,
                                   recoveryGate: device.isolatedGate())
        let inventory = try RetainedKeychainWalletDiscovery.inventory(keystore: device.keychain,
                                                                      recoveryGate: device.isolatedGate())
        let addresses = Set(inventory.adoptable.map(\.address))
        XCTAssertEqual(addresses, [account.address])
        XCTAssertThrowsError(try owner.authorizeRetained("135790", addresses: addresses)) {
            XCTAssertEqual($0 as? WalletRetainedPinGate.Failure, .incorrectPin(attemptsBeforeWait: 2))
        }
        XCTAssertTrue(try device.keychain.checkKey(for: account.address + WalletOwnerPIN.throttleSuffix))
        let grant = try owner.authorizeRetained("246810", addresses: addresses)
        let result = RetainedKeychainWalletDiscovery.restore(
            inventory.adoptable, keystore: device.keychain,
            selectedWalletSettings: try device.selectedWalletSettings(),
            lifecycleCoordinator: device.coordinator, recoveryGate: device.isolatedGate(),
            prepareOwnership: { try owner.prepareRebinding(address: $0.address, to: "246810") },
            ownershipAuthorization: grant)
        XCTAssertTrue(result.failedAddresses.isEmpty, String(describing: result.firstError))
        XCTAssertEqual(result.restored.map(\.address), [account.address])
        try owner.settleRebindings(currentAddresses: [account.address])
        try owner.setInitialPIN("246810", accounts: result.restored)

        let after = try device.keychain.bytes()
        XCTAssertEqual(after[KeystoreTag.pincode.rawValue], Data("246810".utf8))
        XCTAssertEqual(Set(after.keys), Set(before.keys))
        for tag in [KeystoreTag.secretKeyTagForAddress(account.address), KeystoreTag.entropyTagForAddress(account.address),
                    KeystoreTag.seedTagForAddress(account.address)] {
            XCTAssertEqual(after[tag], before[tag], tag)
        }
        XCTAssertEqual(try WalletOwnerPIN.boundAddresses(keystore: device.keychain), [account.address])
        XCTAssertEqual(try owner.verifyRetained("246810", addresses: [account.address]), [account.address])
    }
}

final class RetainedMaterialPreparationBoundaryTests: XCTestCase {
    private func cannotAuthorizeCredentialRepair(_ prepared: PreparedAccount) {
        XCTAssertThrowsError(try prepared.credentialRepairMaterial()) {
            guard case WalletCredentialRepair.Failure.suppliedMaterialRequired = $0 else {
                return XCTFail("Unexpected repair authorization error: \($0)")
            }
        }
    }
    private func prepareSeedOnly(_ crypto: CryptoType) throws {
        let device = try Installation(), reference = InMemoryKeychain()
        let seed = Data(repeating: 0x31, count: 32)
        let expected = try HistoricalWriter.seedImport(seed, cryptoType: crypto, keystore: reference)
        try device.keychain.base.saveSeed(seed, address: expected.address)
        let before = try device.keychain.bytes(), gate = device.isolatedGate()
        let wallet = try XCTUnwrap(RetainedKeychainWalletDiscovery.prove(address: expected.address, keystore: device.keychain, recoveryGate: gate))
        XCTAssertEqual(wallet.cryptoType, crypto); XCTAssertEqual(wallet.publicKey, expected.publicKeyData); XCTAssertFalse(wallet.hasPhrase)
        let prepared = try RetainedKeychainWalletDiscovery.preparedAccount(for: wallet, username: "Retained seed", keystore: device.keychain, recoveryGate: gate)
        defer { prepared.discard() }
        XCTAssertEqual(prepared.account.address, expected.address); XCTAssertEqual(prepared.account.publicKeyData, expected.publicKeyData)
        XCTAssertEqual(prepared.account.username, "Retained seed"); XCTAssertEqual(prepared.account.cryptoType, crypto)
        cannotAuthorizeCredentialRepair(prepared)
        try prepared.prepareInitialPINSetup(keystore: device.keychain, settings: device.settings, operationID: UUID())
        XCTAssertEqual(try device.keychain.bytes(), before); XCTAssertTrue(device.keychain.added.isEmpty); XCTAssertFalse(device.keychain.changedExistingItems)
    }
    private func preparePhraseOnly(_ crypto: CryptoType, path: String) throws {
        let device = try Installation(), reference = InMemoryKeychain()
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: Data(repeating: 0x32, count: 16))
        let expected = try HistoricalWriter.phraseImport(mnemonic.toString(), path: path, cryptoType: crypto, keystore: reference)
        try device.keychain.base.saveEntropy(mnemonic.entropy(), address: expected.address)
        if !path.isEmpty { try device.keychain.base.saveDeriviation(path, address: expected.address) }
        let before = try device.keychain.bytes(), gate = device.isolatedGate()
        let wallet = try XCTUnwrap(RetainedKeychainWalletDiscovery.prove(address: expected.address, keystore: device.keychain, recoveryGate: gate))
        XCTAssertEqual(wallet.cryptoType, crypto); XCTAssertTrue(wallet.hasPhrase); XCTAssertEqual(wallet.derivationPath ?? "", path)
        let prepared = try RetainedKeychainWalletDiscovery.preparedAccount(for: wallet, username: "Retained phrase", keystore: device.keychain, recoveryGate: gate)
        defer { prepared.discard() }
        cannotAuthorizeCredentialRepair(prepared)
        try prepared.prepareInitialPINSetup(keystore: device.keychain, settings: device.settings, operationID: UUID())
        XCTAssertEqual(prepared.account.address, expected.address); XCTAssertEqual(prepared.account.publicKeyData, expected.publicKeyData)
        XCTAssertEqual(prepared.account.cryptoType, crypto); XCTAssertEqual(prepared.account.username, "Retained phrase")
        XCTAssertEqual(try device.keychain.bytes(), before); XCTAssertTrue(device.keychain.added.isEmpty); XCTAssertFalse(device.keychain.changedExistingItems)
    }
    func testSr25519SeedAloneProvesAndPreparesTheRetainedIdentityWithoutWrites() throws { try prepareSeedOnly(.sr25519) }
    func testEd25519SeedAloneProvesAndPreparesTheRetainedIdentityWithoutWrites() throws { try prepareSeedOnly(.ed25519) }
    func testEcdsaSeedAloneProvesAndPreparesTheRetainedIdentityWithoutWrites() throws { try prepareSeedOnly(.ecdsa) }
    func testSr25519PhraseAndSoftPathPrepareWithoutAddingSecretTags() throws { try preparePhraseOnly(.sr25519, path: "/soft") }
    func testEd25519PhraseAndHardPathPrepareWithoutAddingSecretTags() throws { try preparePhraseOnly(.ed25519, path: "//hard") }
    func testEcdsaPhraseAndHardPathPrepareWithoutAddingSecretTags() throws { try preparePhraseOnly(.ecdsa, path: "//hard") }
    func testChangedSeedAfterDiscoveryCannotPrepareThePreviouslyProvenWallet() throws {
        let device = try Installation(), reference = InMemoryKeychain()
        let account = try HistoricalWriter.seedImport(Data(repeating: 0x33, count: 32), cryptoType: .ed25519, keystore: reference)
        try device.keychain.base.saveSeed(Data(repeating: 0x33, count: 32), address: account.address)
        let gate = device.isolatedGate(), wallet = try XCTUnwrap(RetainedKeychainWalletDiscovery.prove(address: account.address, keystore: device.keychain, recoveryGate: device.isolatedGate()))
        try device.keychain.base.saveSeed(Data(repeating: 0x34, count: 32), address: account.address)
        let before = try device.keychain.bytes()
        XCTAssertThrowsError(try RetainedKeychainWalletDiscovery.preparedAccount(for: wallet, username: "Stale", keystore: device.keychain, recoveryGate: gate)) {
            guard case AccountCreateError.retainedKeyConflict = $0 else { return XCTFail("Unexpected error: \($0)") }
        }
        XCTAssertEqual(try device.keychain.bytes(), before); XCTAssertTrue(device.keychain.added.isEmpty)
    }
    func testSeedUnderAnotherAddressIsUnprovableAndRemainsUntouched() throws {
        let device = try Installation(), reference = InMemoryKeychain()
        let account = try HistoricalWriter.seedImport(Data(repeating: 0x35, count: 32), cryptoType: .sr25519, keystore: reference)
        try device.keychain.base.saveSeed(Data(repeating: 0x36, count: 32), address: account.address)
        let before = try device.keychain.bytes()
        XCTAssertNil(try RetainedKeychainWalletDiscovery.prove(address: account.address, keystore: device.keychain, recoveryGate: device.isolatedGate()))
        XCTAssertEqual(try device.keychain.bytes(), before)
    }
    func testForeignNetworkAddressIsRejectedBeforeAdoptingItsTags() throws {
        let device = try Installation(), reference = InMemoryKeychain()
        let account = try HistoricalWriter.seedImport(Data(repeating: 0x37, count: 32), cryptoType: .sr25519, keystore: reference)
        let foreign = try SS58AddressFactory().address(fromAccountId: account.publicKeyData, type: 42)
        try device.keychain.base.saveSeed(Data(repeating: 0x37, count: 32), address: foreign)
        let before = try device.keychain.bytes()
        XCTAssertNil(try RetainedKeychainWalletDiscovery.prove(address: foreign, keystore: device.keychain, recoveryGate: device.isolatedGate()))
        XCTAssertEqual(try device.keychain.bytes(), before)
    }
    func testAddressWithoutRetainedMaterialDoesNotProduceARecoveryCandidate() throws {
        let device = try Installation(), reference = InMemoryKeychain()
        let account = try HistoricalWriter.seedImport(Data(repeating: 0x38, count: 32), cryptoType: .ed25519, keystore: reference)
        XCTAssertNil(try RetainedKeychainWalletDiscovery.prove(address: account.address, keystore: device.keychain, recoveryGate: device.isolatedGate()))
        XCTAssertTrue(try device.keychain.bytes().isEmpty)
    }
    func testChangedDerivationPathCannotPrepareAnotherAccountFromTheRetainedPhrase() throws {
        let device = try Installation(), reference = InMemoryKeychain()
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: Data(repeating: 0x39, count: 16))
        let account = try HistoricalWriter.phraseImport(mnemonic.toString(), path: "//one", keystore: reference)
        try device.keychain.base.saveEntropy(mnemonic.entropy(), address: account.address)
        try device.keychain.base.saveDeriviation("//two", address: account.address)
        let before = try device.keychain.bytes()
        XCTAssertNil(try RetainedKeychainWalletDiscovery.prove(address: account.address, keystore: device.keychain, recoveryGate: device.isolatedGate()))
        XCTAssertEqual(try device.keychain.bytes(), before)
    }
    func testPreparedRetainedMaterialDoesNotGrantInitialPinSetupByItself() throws {
        let device = try Installation(), reference = InMemoryKeychain()
        let seed = Data(repeating: 0x3a, count: 32)
        let account = try HistoricalWriter.seedImport(seed, cryptoType: .ed25519, keystore: reference)
        try device.keychain.base.saveSeed(seed, address: account.address)
        let gate = device.isolatedGate(), wallet = try XCTUnwrap(RetainedKeychainWalletDiscovery.prove(address: account.address, keystore: device.keychain, recoveryGate: device.isolatedGate()))
        let prepared = try RetainedKeychainWalletDiscovery.preparedAccount(for: wallet, username: "Unowned", keystore: device.keychain, recoveryGate: gate)
        defer { prepared.discard() }
        let before = try device.keychain.bytes()
        try prepared.prepareInitialPINSetup(keystore: device.keychain, settings: device.settings, operationID: UUID())
        XCTAssertEqual(try device.keychain.bytes(), before); XCTAssertTrue(device.keychain.added.isEmpty)
    }

    func testPreparedGlobalEntropyCannotCreateAnInitialPinSetupClaim() throws {
        let device = try Installation()
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: Data(repeating: 0x3b, count: 20))
        _ = try HistoricalWriter.version1(phrase: mnemonic.toString(), keystore: device.keychain.base)
        let gate = device.isolatedGate()
        let inventory = try RetainedKeychainWalletDiscovery.inventory(keystore: device.keychain, recoveryGate: gate)
        let wallet = try XCTUnwrap(inventory.adoptable.first(where: \.usesGlobalEntropy))
        let prepared = try RetainedKeychainWalletDiscovery.preparedAccount(for: wallet, username: "Earlier wallet", keystore: device.keychain, recoveryGate: gate)
        defer { prepared.discard() }
        cannotAuthorizeCredentialRepair(prepared)
        let before = try device.keychain.bytes()
        try prepared.prepareInitialPINSetup(keystore: device.keychain, settings: device.settings, operationID: UUID())
        XCTAssertEqual(try device.keychain.bytes(), before)
        XCTAssertFalse(try WalletOwnerPIN(keystore: device.keychain, settings: device.settings, recoveryGate: gate).requiresInitialSetup(accounts: [prepared.account]))
    }

    func testPreparedDirectSecretCannotCreateAnInitialPinSetupClaim() throws {
        let device = try Installation()
        let account = try HistoricalWriter.seedImport(Data(repeating: 0x3c, count: 32), cryptoType: .ecdsa, keystore: device.keychain.base)
        let gate = device.isolatedGate()
        let wallet = try XCTUnwrap(RetainedKeychainWalletDiscovery.prove(address: account.address, keystore: device.keychain, recoveryGate: gate))
        let prepared = try RetainedKeychainWalletDiscovery.preparedAccount(for: wallet, username: "Earlier wallet", keystore: device.keychain, recoveryGate: gate)
        defer { prepared.discard() }
        let before = try device.keychain.bytes()
        try prepared.prepareInitialPINSetup(keystore: device.keychain, settings: device.settings, operationID: UUID())
        XCTAssertEqual(try device.keychain.bytes(), before)
        XCTAssertFalse(try WalletOwnerPIN(keystore: device.keychain, settings: device.settings, recoveryGate: gate).requiresInitialSetup(accounts: [account]))
    }

    func testSeedOnlyPreparationCanUseASeparatelyVerifiedOwnerGrant() throws {
        let device = try Installation(), reference = InMemoryKeychain()
        let seed = Data(repeating: 0x3d, count: 32)
        let account = try HistoricalWriter.seedImport(seed, cryptoType: .ed25519, keystore: reference)
        try device.keychain.base.saveSeed(seed, address: account.address)
        try device.keychain.base.saveKey(JSONEncoder().encode(WalletOwnerPIN.Binding(pin: "123456")), with: account.address + WalletOwnerPIN.bindingSuffix)
        let gate = device.isolatedGate(), owner = WalletOwnerPIN(keystore: device.keychain, settings: device.settings, recoveryGate: device.isolatedGate())
        let grant = try owner.authorizeRetained("123456", addresses: [account.address])
        let wallet = try XCTUnwrap(RetainedKeychainWalletDiscovery.prove(address: account.address, keystore: device.keychain, recoveryGate: gate))
        let prepared = try RetainedKeychainWalletDiscovery.preparedAccount(for: wallet, username: "Authorized wallet", keystore: device.keychain, recoveryGate: gate)
        defer { prepared.discard() }
        prepared.restrictToRetainedOwnership(grant)
        try prepared.prepareInitialPINSetup(keystore: device.keychain, settings: device.settings, operationID: UUID())
        XCTAssertTrue(try owner.requiresInitialSetup(accounts: [account]))
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.seedTagForAddress(account.address)), seed)
        cannotAuthorizeCredentialRepair(prepared)
    }
}
