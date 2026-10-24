import CoreData
import XCTest
@testable import SoraPassport
import IrohaCrypto
import SoraKeystore

final class WalletRecoveryExitsTests: XCTestCase {
    private var directories: [URL] = []

    override func tearDownWithError() throws {
        for directory in directories {
            try? FileManager.default.removeItem(at: directory)
        }
        directories = []
    }

    // MARK: Keychain scan

    func testScannerOffersWalletWhoseKeychainMaterialReDerivesItsAddress() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519, keychain: keychain, settings: settings)
        let account = try XCTUnwrap(settings.currentAccount)

        let wallets = try WalletRecoveryKeychainScanner.wallets(
            keystore: keychain,
            settings: settings,
            displayNames: [account.address: "Main"]
        )

        XCTAssertEqual(wallets, [
            WalletRecoveryKeychainWallet(
                address: account.address,
                cryptoType: .sr25519,
                derivationPath: "",
                source: .scopedEntropy,
                displayName: "Main"
            ),
        ])
    }

    func testScannerProvesDerivedEd25519AndSeedOnlyWallets() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()
        try AccountCreationHelper.createAccountFromMnemonic(
            cryptoType: .ed25519,
            derivationPath: "//soraneo",
            keychain: keychain,
            settings: settings
        )
        let derived = try XCTUnwrap(settings.currentAccount)
        try AccountCreationHelper.createAccountFromSeed(
            String(repeating: "ab", count: 32),
            cryptoType: .sr25519,
            keychain: keychain,
            settings: settings
        )
        let seeded = try XCTUnwrap(settings.currentAccount)

        let wallets = try WalletRecoveryKeychainScanner.wallets(keystore: keychain, settings: settings)

        XCTAssertEqual(Set(wallets.map(\.address)), [derived.address, seeded.address])
        let derivedWallet = try XCTUnwrap(wallets.first { $0.address == derived.address })
        XCTAssertEqual(derivedWallet.cryptoType, .ed25519)
        XCTAssertEqual(derivedWallet.derivationPath, "//soraneo")
        XCTAssertEqual(derivedWallet.source, .scopedEntropy)
        let seededWallet = try XCTUnwrap(wallets.first { $0.address == seeded.address })
        XCTAssertEqual(seededWallet.source, .scopedSeed)
        XCTAssertEqual(seededWallet.displayName, WalletRecoveryKeychainScanner.defaultDisplayName)
    }

    func testScannerRejectsMaterialStoredUnderAnotherAddress() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519, keychain: keychain, settings: settings)
        let kept = try XCTUnwrap(settings.currentAccount)
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519, keychain: keychain, settings: settings)
        let swapped = try XCTUnwrap(settings.currentAccount)
        let foreign = try keychain.fetchKey(for: KeystoreTag.entropyTagForAddress(kept.address))
        try keychain.updateKey(foreign, with: KeystoreTag.entropyTagForAddress(swapped.address))

        let wallets = try WalletRecoveryKeychainScanner.wallets(keystore: keychain, settings: settings)

        XCTAssertEqual(wallets.map(\.address), [kept.address])
    }

    func testScannerNeverOffersRetiredRecords() throws {
        let source = InMemoryKeychain()
        let settings = InMemorySettingsManager()
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519, keychain: source, settings: settings)
        let keychain = InMemoryKeychain()
        for tag in try source.allKeyIdentifiers() {
            try keychain.addKey(
                try source.fetchKey(for: tag),
                with: WalletRecoveryFreshStart.retiredTag(for: tag, archiveId: "20261024T000000Z-test")
            )
        }

        XCTAssertEqual(try WalletRecoveryKeychainScanner.wallets(keystore: keychain, settings: settings), [])
        XCTAssertFalse(try keychain.hasRetainedWalletMaterial())
    }

    func testOnlyMissingOrAccountlessDatabasesLeaveTheKeychainAsTheWalletRecord() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WalletRecoveryExitsTests-\(UUID().uuidString)", isDirectory: true)
        directories.append(root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storeURL = root.appendingPathComponent("UserDataModel.sqlite")
        XCTAssertTrue(WalletRecoveryKeychainScanner.walletDatabaseHasNoAccounts(storeURL: storeURL))

        let name = UserStorageParams.modelVersion.rawValue
        let directory = UserStorageParams.modelDirectory
        let modelURL = try XCTUnwrap(
            Bundle.main.url(forResource: name, withExtension: "omo", subdirectory: directory)
                ?? Bundle.main.url(forResource: name, withExtension: "mom", subdirectory: directory)
        )
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL)
        XCTAssertTrue(WalletRecoveryKeychainScanner.walletDatabaseHasNoAccounts(storeURL: storeURL))

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        NSEntityDescription.insertNewObject(forEntityName: "CDAccountItem", into: context)
            .setValue("cnAccount", forKey: "identifier")
        try context.save()
        try coordinator.remove(store)
        XCTAssertFalse(WalletRecoveryKeychainScanner.walletDatabaseHasNoAccounts(storeURL: storeURL))

        let unreadable = root.appendingPathComponent("unreadable.sqlite")
        try Data("not a database".utf8).write(to: unreadable)
        XCTAssertFalse(WalletRecoveryKeychainScanner.walletDatabaseHasNoAccounts(storeURL: unreadable))
    }

    // MARK: Setting aside

    func testStartingOverMovesStateAsideRetiresKeychainAndClearsRecovery() throws {
        let fixture = try makeInstalledWallet()
        let keychain = fixture.keychain
        let settings = fixture.settings
        let walletTags = try keychain.allKeyIdentifiers().filter { $0 != "unrelated" }
        var values: [String: Data] = [:]
        for tag in walletTags {
            values[tag] = try keychain.fetchKey(for: tag)
        }
        var closedDatabase = false

        let outcome = try WalletRecoveryFreshStart.setAside(
            retiringKeychainMaterial: true,
            keystore: keychain,
            settings: settings,
            fileManager: .default,
            databaseDirectoryURL: fixture.databaseDirectory,
            applicationSupportURL: fixture.applicationSupport,
            closeDatabase: { closedDatabase = true }
        )

        XCTAssertTrue(closedDatabase)
        XCTAssertEqual(outcome.movedItems, ["CoreData", "WalletNetworks", "WalletAccountCommits"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.databaseDirectory.path))
        for path in [
            "CoreData/UserDataModel.sqlite-wal",
            "CoreData/WalletMigrationSafety/backup.sqlite",
            "WalletNetworks/active.json",
            "WalletAccountCommits/journal.json",
            "settings.plist",
            "manifest.json",
        ] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: outcome.archiveURL.appendingPathComponent(path).path),
                path
            )
        }

        XCTAssertEqual(outcome.retiredKeychainRecords, walletTags.count)
        for tag in walletTags {
            XCTAssertFalse(try keychain.checkKey(for: tag), tag)
            XCTAssertEqual(
                try keychain.fetchKey(for: WalletRecoveryFreshStart.retiredTag(for: tag, archiveId: outcome.archiveId)),
                values[tag],
                tag
            )
        }
        XCTAssertTrue(try keychain.checkKey(for: "unrelated"))
        XCTAssertFalse(try keychain.hasRetainedWalletMaterial())
        XCTAssertEqual(try WalletRecoveryKeychainScanner.wallets(keystore: keychain, settings: settings), [])

        XCTAssertFalse(settings.walletMigrationRecoveryRequired)
        XCTAssertFalse(settings.hasRetainedWalletSettings())
        XCTAssertFalse(settings.hasRetainedWatchOnlyWallet())
        XCTAssertNil(settings.anyValue(for: SettingsKey.failInputPinCount.rawValue))
        XCTAssertNil(settings.anyValue(for: SettingsKey.walletStartupDiagnostic.rawValue))
        XCTAssertEqual(settings.string(for: SettingsKey.selectedLocalization.rawValue), "ja")
        XCTAssertEqual(settings.anyValue(for: WalletRecoveryFreshStart.archivesSettingsKey) as? [String], [outcome.archiveId])

        let archivedSettings = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: outcome.archiveURL.appendingPathComponent("settings.plist")),
            format: nil
        ) as? [String: Any]
        XCTAssertNotNil(archivedSettings?[SettingsKey.selectedAccount.rawValue])
        XCTAssertNotNil(archivedSettings?[SettingsKey.walletMigrationRecoveryRecord.rawValue])
    }

    func testRestoringFromKeychainKeepsKeysPinAndAttemptCounters() throws {
        let fixture = try makeInstalledWallet()
        let identifiers = try fixture.keychain.allKeyIdentifiers()

        let outcome = try WalletRecoveryFreshStart.setAside(
            retiringKeychainMaterial: false,
            keystore: fixture.keychain,
            settings: fixture.settings,
            fileManager: .default,
            databaseDirectoryURL: fixture.databaseDirectory,
            applicationSupportURL: fixture.applicationSupport,
            closeDatabase: {}
        )

        XCTAssertEqual(outcome.retiredKeychainRecords, 0)
        XCTAssertEqual(try fixture.keychain.allKeyIdentifiers(), identifiers)
        XCTAssertEqual(fixture.settings.integer(for: SettingsKey.failInputPinCount.rawValue), 3)
        XCTAssertNil(fixture.settings.anyValue(for: SettingsKey.selectedAccount.rawValue))
        XCTAssertFalse(fixture.settings.walletMigrationRecoveryRequired)
        XCTAssertEqual(
            try WalletRecoveryKeychainScanner.wallets(keystore: fixture.keychain, settings: fixture.settings)
                .map(\.address),
            [fixture.account.address]
        )
    }

    // MARK: PIN attempts across a reinstall

    func testPinAttemptsAndWaitOutliveSettingsAndKeepEscalating() throws {
        let attempts = InMemoryKeychain()
        let blockedUntil = Int(Date().addingTimeInterval(600).timeIntervalSince1970)
        PinAttemptRecord(failures: 4, blockedUntil: blockedUntil).save(to: attempts)
        let secrets = InMemoryKeychainManager()
        try secrets.keychain.addKey(Data("123456".utf8), with: KeystoreTag.pincode.rawValue)

        // A reinstall deletes settings but keeps the Keychain.
        let interactor = LocalAuthInteractor(
            secretManager: secrets,
            settingsManager: InMemorySettingsManager(),
            biometryAuth: NoBiometry(),
            locale: .current,
            attemptStore: attempts
        )
        XCTAssertEqual(interactor.getInputBlockDate().map { Int($0.timeIntervalSince1970) }, blockedUntil)

        interactor.process(pin: "000000")
        let checked = expectation(description: "wrong PIN processed")
        DispatchQueue.main.async { checked.fulfill() }
        wait(for: [checked], timeout: 5)

        let record = try XCTUnwrap(PinAttemptRecord.load(from: attempts))
        XCTAssertEqual(record.failures, 5)
        XCTAssertGreaterThan(
            try XCTUnwrap(record.blockedUntil),
            Int(Date().addingTimeInterval(14 * 60).timeIntervalSince1970)
        )
    }

    // MARK: Import over retained records

    func testImportReusesIdenticalKeychainRecordsButNeverReplacesDifferentOnes() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()
        let phrase = try IRMnemonicCreator().randomMnemonic(.entropy128).toString()
        try AccountCreationHelper.createAccountFromMnemonic(phrase, cryptoType: .sr25519, keychain: keychain, settings: settings)
        let account = try XCTUnwrap(settings.currentAccount)
        let identifiers = try keychain.allKeyIdentifiers()

        // The same phrase again, as after a lost database or a reinstall.
        XCTAssertNoThrow(try AccountCreationHelper.createAccountFromMnemonic(
            phrase, cryptoType: .sr25519, keychain: keychain, settings: settings
        ))
        XCTAssertEqual(try keychain.allKeyIdentifiers(), identifiers)

        let seedTag = KeystoreTag.seedTagForAddress(account.address)
        let entropyTag = KeystoreTag.entropyTagForAddress(account.address)
        try keychain.updateKey(Data(repeating: 7, count: 32), with: seedTag)
        try keychain.deleteKey(for: entropyTag)

        XCTAssertThrowsError(try AccountCreationHelper.createAccountFromMnemonic(
            phrase, cryptoType: .sr25519, keychain: keychain, settings: settings
        )) { error in
            guard case AccountCreateError.duplicated = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
        XCTAssertEqual(try keychain.fetchKey(for: seedTag), Data(repeating: 7, count: 32))
        XCTAssertFalse(try keychain.checkKey(for: entropyTag))
    }

    // MARK: Fixtures

    private struct InstalledWallet {
        let keychain: InMemoryKeychain
        let settings: InMemorySettingsManager
        let account: AccountItem
        let databaseDirectory: URL
        let applicationSupport: URL
    }

    private func makeInstalledWallet() throws -> InstalledWallet {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WalletRecoveryExitsTests-\(UUID().uuidString)", isDirectory: true)
        directories.append(root)
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        let support = root.appendingPathComponent("Application Support", isDirectory: true)
        let databaseDirectory = documents.appendingPathComponent("CoreData", isDirectory: true)
        try write("wal", to: databaseDirectory.appendingPathComponent("UserDataModel.sqlite-wal"))
        try write("copy", to: databaseDirectory.appendingPathComponent("WalletMigrationSafety/backup.sqlite"))
        try write("{}", to: support.appendingPathComponent("SORA/WalletNetworks/active.json"))
        try write("{}", to: support.appendingPathComponent("SORA/WalletAccountCommits/journal.json"))

        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519, keychain: keychain, settings: settings)
        let account = try XCTUnwrap(settings.currentAccount)
        try keychain.addKey(Data("1234".utf8), with: KeystoreTag.pincode.rawValue)
        PinAttemptRecord(failures: 2, blockedUntil: nil).save(to: keychain)
        try keychain.addKey(Data([1]), with: "unrelated")
        settings.setWalletMigrationRecovery(reason: "Wallet storage could not be verified safely (missing_wallet_store). Existing wallet data and recovery copies were preserved.")
        settings.set(value: "{}", for: SettingsKey.walletStartupDiagnostic.rawValue)
        settings.set(value: 3, for: SettingsKey.failInputPinCount.rawValue)
        settings.set(value: true, for: "wallet.watchOnly.\(account.address)")
        settings.set(value: "ja", for: SettingsKey.selectedLocalization.rawValue)
        return InstalledWallet(
            keychain: keychain,
            settings: settings,
            account: account,
            databaseDirectory: databaseDirectory,
            applicationSupport: support
        )
    }

    private final class NoBiometry: BiometryAuthProtocol {
        var availableBiometryType: AvailableBiometryType { .none }
        func authenticate(localizedReason: String, completionQueue: DispatchQueue,
                          completionBlock: @escaping (Bool) -> Void) {
            completionQueue.async { completionBlock(false) }
        }
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }
}
