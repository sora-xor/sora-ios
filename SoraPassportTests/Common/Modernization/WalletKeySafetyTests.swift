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
                  afterCopy: ((URL) throws -> Void)? = nil) throws -> UserStorageMigrator {
        let store = try networkStore()
        return UserStorageMigrator(targetVersion: .version2, storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory, keystore: keychain, settings: settings,
            fileManager: .default, recoveryGate: gate ?? self.gate(), migrationRecoveryMarker: marker,
            availableCapacity: { _ in Int64.max }, loadWalletNetworkSnapshot: { try store.load() },
            afterLegacyStoreCopyBeforeVerification: afterCopy)
    }

    /// The production startup sequence of `SplashInteractor`, against this
    /// installation: journal and startup recovery, database migration, then
    /// the network bootstrap and the scoped-copy backfill.
    @discardableResult
    func startup(migration: (() throws -> Void)? = nil) throws -> WalletStorageStartupOutcome {
        let gate = self.gate()
        let coordinator = WalletLifecycleCoordinator(recoveryGate: gate)
        let database = try migrator(gate: gate)
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

    func rootDecision(selected: AccountItem?) throws -> [KeySafetyRootPresenterSpy.Decision] {
        let store = try networkStore()
        let root = RootInteractor(settings: settings, keystore: keychain, migrators: [],
            securityLayerInteractor: KeySafetySecurityLayerStub(), networkAvailabilityLayerInteractor: nil,
            legacyUpgradeSelectedAccount: { selected }, legacyUpgradeSnapshotLoader: { try store.load() },
            legacyUpgradeUnresolvedCommitLoader: { [] })
        let spy = KeySafetyRootPresenterSpy()
        root.presenter = spy
        root.decideModuleSynchroniously()
        return spy.decisions
    }

    /// `SelectedWalletSettings` over an in-memory Core Data stack whose
    /// network synchronizer writes this installation's snapshot.
    func selectedWalletSettings(accounts: [AccountItem] = []) throws -> SelectedWalletSettings {
        let facade = UserDataStorageTestFacade()
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
            lifecycleCoordinator: coordinator, recoveryGate: gate)
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
                XCTAssertEqual(try device.keychain.bytes(),
                               [KeystoreTag.entropyTagForAddress(account.address): try reference.base.fetchKey(
                                   for: KeystoreTag.entropyTagForAddress(account.address))])
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
            XCTAssertThrowsError(try device.importPhrase(phrase12, into: device.selectedWalletSettings()), conflict) {
                guard case AccountCreateError.retainedKeyConflict = $0 else { return XCTFail("\(conflict): \($0)") }
            }
            XCTAssertEqual(device.keychain.added, [], conflict)
            XCTAssertFalse(device.keychain.changedExistingItems, conflict)
            XCTAssertEqual(try device.keychain.bytes(), retained, conflict)
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

        // The PIN gate counts failures and closes after five.
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("246810".utf8))
        do {
            try WalletRetainedPinGate.verify("000000", keystore: device.keychain, settings: device.settings)
            XCTFail("A wrong PIN was accepted")
        } catch {
            XCTAssertEqual(error as? WalletRetainedPinGate.Failure, .incorrectPin(remainingAttempts: 4))
        }
        XCTAssertEqual(device.settings.integer(for: WalletRetainedPinGate.failureCountKey), 1)
        XCTAssertEqual(try device.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data("246810".utf8))
        XCTAssertNoThrow(try WalletRetainedPinGate.verify("246810", keystore: device.keychain, settings: device.settings))
        XCTAssertNil(device.settings.integer(for: WalletRetainedPinGate.failureCountKey))

        let restored = try RetainedKeychainWalletDiscovery.restore(inventory.adoptable, keystore: device.keychain,
            selectedWalletSettings: device.selectedWalletSettings(),
            lifecycleCoordinator: device.coordinator,
            recoveryGate: device.isolatedGate())
        XCTAssertEqual(Set(restored.map(\.address)), Set(inventory.adoptable.map(\.address)))
        XCTAssertEqual(device.keychain.added, [])
        XCTAssertFalse(device.keychain.changedExistingItems)
        XCTAssertEqual(try device.keychain.bytes(), retained)
        let snapshot = try XCTUnwrap(device.networkStore().load())
        XCTAssertEqual(Set(snapshot.wallets.map(\.id)), Set(restored.map(\.address)))
        XCTAssertEqual(snapshot.selectedWalletId, inventory.adoptable.first?.address)
        XCTAssertFalse(snapshot.wallets.contains { $0.secretSource == .signingUnavailable })

        for _ in 0..<5 {
            _ = try? WalletRetainedPinGate.verify("111111", keystore: device.keychain, settings: device.settings)
        }
        XCTAssertThrowsError(try WalletRetainedPinGate.verify("246810", keystore: device.keychain, settings: device.settings)) {
            XCTAssertEqual($0 as? WalletRetainedPinGate.Failure, .locked)
        }
        XCTAssertFalse(WalletRecoveryStateProbe.welcomeBack(keystore: device.keychain, settings: device.settings)
            .options.canRestoreExistingKeys)
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
            XCTAssertEqual(restored.keychain.added, [KeystoreTag.entropyTagForAddress(first.address)])
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
        XCTAssertEqual(device.keychain.added, [KeystoreTag.entropyTagForAddress(keyless.address)])
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
}
