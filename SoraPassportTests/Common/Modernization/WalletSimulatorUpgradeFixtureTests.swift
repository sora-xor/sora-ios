// Test-target-only real-sandbox fixtures. Never compiled into a shipping app.
// These public wallets are created only on an explicitly opted-in disposable simulator.
import CoreData
import CryptoKit
import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCrypto
import SSFUtils
import XCTest
@testable import SoraPassport

final class WalletSimulatorUpgradeFixtureTests: XCTestCase {
    private let keys = Keychain()
    private var caseName: String { ProcessInfo.processInfo.environment["SORA_SIMULATOR_CASE"] ?? "" }
    private var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private var receiptURL: URL { documents.appendingPathComponent("simulator-upgrade-fixture.json") }
    private var markerURL: URL { documents.appendingPathComponent("simulator-public-fixtures-only.marker") }
    private let pin = "123456"
    private let replacementPIN = "654321"
    private var phase: String { ProcessInfo.processInfo.environment["SORA_SIMULATOR_PHASE"] ?? "single" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        #if targetEnvironment(simulator)
        let env = ProcessInfo.processInfo.environment
        guard env["SORA_SIMULATOR_FIXTURES"] == "PUBLIC_FIXTURES_ONLY",
              let expected = env["SORA_SIMULATOR_EXPECTED_UDID"], !expected.isEmpty,
              env["SIMULATOR_UDID"] == expected,
              Bundle.main.bundleIdentifier == "co.jp.soramitsu.sora.dev",
              ProcessInfo.processInfo.arguments.contains("-UNITTEST"), !caseName.isEmpty else {
            throw XCTSkip("Opt-in fixture writer requires its disposable simulator UUID, development test host, and public-fixture authorization")
        }
        #else
        throw XCTSkip("Simulator fixtures must never run on a physical device")
        #endif
    }

    private func vectors(_ resource: String = "ios-386-vectors") throws -> [[String: Any]] {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: resource, withExtension: "json", subdirectory: "HistoricalCrypto"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try XCTUnwrap(root["vectors"] as? [[String: Any]])
    }

    private func clearOwnedFixture() throws {
        let fm = FileManager.default
        let uuid = try XCTUnwrap(ProcessInfo.processInfo.environment["SIMULATOR_UDID"])
        if fm.fileExists(atPath: markerURL.path) {
            XCTAssertEqual(try String(contentsOf: markerURL, encoding: .utf8), uuid)
        } else {
            // No marker means a fresh installation, never permission to erase a wallet.
            XCTAssertTrue(try keys.allKeyIdentifiers().isEmpty)
            XCTAssertFalse(fm.fileExists(atPath: UserStorageParams.storageURL.path))
            XCTAssertFalse(SettingsManager.shared.hasRetainedWalletSettings())
        }
        for tag in try keys.allKeyIdentifiers() { try keys.deleteKey(for: tag) }
        for child in try fm.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) {
            try fm.removeItem(at: child)
        }
        let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let sora = support.appendingPathComponent("SORA")
        if fm.fileExists(atPath: sora.path) { try fm.removeItem(at: sora) }
        SettingsManager.shared.removeAll()
        SettingsManager.shared.biometryEnabled = false
        UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        try Data(uuid.utf8).write(to: markerURL, options: .atomic)
    }

    private func releasedPhrase(_ vector: [String: Any], index: Int) throws -> AccountItem {
        let phrase = try XCTUnwrap(vector["phrase"] as? String)
        let crypto = CryptoType(type: try XCTUnwrap(vector["cryptoType"] as? String).uppercased())
        let request = AccountCreationRequest(username: "Audit \(crypto.typeString) \(index)", type: .sora,
            derivationPath: try XCTUnwrap(vector["derivationPath"] as? String), cryptoType: crypto)
        let operation = SimulatorReleased386AccountOperationFactory(keystore: keys).newAccountOperation(
            request: request, mnemonic: try IRMnemonicCreator(language: .english).mnemonic(fromList: phrase))
        operation.start()
        let account = try XCTUnwrap(operation.result).get()
        // Original dependencies produced these bytes independently; this prevents a
        // current derivation silently defining its own expected identity.
        XCTAssertEqual(account.address, vector["address"] as? String)
        XCTAssertEqual(account.publicKeyData, try Data(hex: XCTUnwrap(vector["publicKeyHex"] as? String)))
        let archivedSecret = try Data(hex: XCTUnwrap(vector["secretKeyHex"] as? String))
        let generatedSecret = try XCTUnwrap(keys.fetchSecretKeyForAddress(account.address))
        if crypto == .sr25519 || (crypto == .ed25519 && archivedSecret.count == 64) {
            // sr25519 soft derivation randomizes its nonce half. Old ed25519
            // JSON may retain a redundant (including stale) public half.
            // Check the signing scalar/seed, then install the archived bytes
            // so the next launch must preserve the exact historical record.
            XCTAssertEqual(generatedSecret.prefix(32), archivedSecret.prefix(32))
            try keys.saveSecretKey(archivedSecret, address: account.address)
        } else { XCTAssertEqual(generatedSecret, archivedSecret) }
        return account
    }

    private func expectedImportedAccount(_ vector: [String: Any]) throws -> AccountItem {
        AccountItem(address: try XCTUnwrap(vector["address"] as? String), cryptoType: .sr25519,
            networkType: SNAddressType(chain: .sora), username: "Audit imported phrase",
            publicKeyData: try Data(hex: XCTUnwrap(vector["publicKeyHex"] as? String)),
            settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)
    }

    private func cryptoTags(_ address: String) -> [String] {
        [KeystoreTag.entropyTagForAddress(address), KeystoreTag.seedTagForAddress(address),
         KeystoreTag.secretKeyTagForAddress(address), KeystoreTag.deriviationTagForAddress(address)]
    }

    private func keyHashes(_ tags: [String]) throws -> [String: String] {
        try Dictionary(uniqueKeysWithValues: tags.map { tag in
            (tag, Data(SHA256.hash(data: try keys.fetchKey(for: tag))).map { String(format: "%02x", $0) }.joined())
        })
    }

    private func cryptoState(_ address: String) throws -> [String: String] {
        // A default-path import intentionally has no derivation tag. Preserve
        // that absence as well as every present cryptographic byte.
        try Dictionary(uniqueKeysWithValues: cryptoTags(address).map { tag in
            if try keys.checkKey(for: tag) {
                return (tag, Data(SHA256.hash(data: try keys.fetchKey(for: tag)))
                    .map { String(format: "%02x", $0) }.joined())
            }
            return (tag, "absent")
        })
    }

    private func model(_ version: UserStorageVersion) throws -> NSManagedObjectModel {
        let url = Bundle.main.url(forResource: version.rawValue, withExtension: "mom", subdirectory: UserStorageParams.modelDirectory)
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: XCTUnwrap(url)))
    }

    private func writeRows(_ accounts: [AccountItem], version: UserStorageVersion) throws {
        try FileManager.default.createDirectory(at: UserStorageParams.storageDirectoryURL, withIntermediateDirectories: true)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try model(version))
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
            at: UserStorageParams.storageURL, options: nil)
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for (index, account) in accounts.enumerated() {
                let row = CDAccountItem(context: context)
                if version == .version2 {
                    // Exact App Store 3.8.6 mapper body, only its type renamed.
                    try SimulatorReleased386AccountItemMapper().populate(entity: row, from: account, using: context)
                    row.isSelected = index == 0
                } else {
                    try SimulatorReleased23AccountMapper.populate(entity: row, from: account, using: context)
                }
                row.order = Int16(index)
            }
            try context.save()
        }
    }

    func testPreparePublicHistoricalState() throws {
        try clearOwnedFixture()
        let all = try vectors()
        var accounts: [AccountItem] = []
        var expectedRoute = "wallet"
        var expectedSigning = true
        var expectedRows = true
        var plantedHelpers: [String] = []
        var version: UserStorageVersion = .version2
        if caseName == "fresh-import" {
            let vector = all[9]
            accounts = [AccountItem(address: try XCTUnwrap(vector["address"] as? String), cryptoType: .sr25519,
                networkType: SNAddressType(chain: .sora), username: "Audit imported phrase",
                publicKeyData: try Data(hex: XCTUnwrap(vector["publicKeyHex"] as? String)),
                settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)]
            expectedRoute = "onboarding"
        } else if caseName == "one-x" || caseName == "entropy-only" {
            let old = try XCTUnwrap(vectors("ios-1x-vectors").first { ($0["password"] as? String) == "" })
            // Verbatim released 1.x application tags and raw bytes from original Iroha.
            try keys.saveKey(Data(hex: XCTUnwrap(old["entropyHex"] as? String)), with: "seedEntropy")
            if caseName == "one-x" { try keys.saveKey(Data(hex: XCTUnwrap(old["secretKeyHex"] as? String)), with: "privateKey") }
            SettingsManager.shared.set(value: "Public legacy fixture", for: "userName")
            expectedRoute = "legacy"
            let substrate = try XCTUnwrap(vectors("ios-386-long-phrases").first)
            XCTAssertEqual(old["phrase"] as? String, substrate["phrase"] as? String)
            accounts = [AccountItem(address: try XCTUnwrap(substrate["address"] as? String), cryptoType: .sr25519,
                networkType: SNAddressType(chain: .sora), username: "Public legacy fixture",
                publicKeyData: try Data(hex: XCTUnwrap(substrate["publicKeyHex"] as? String)),
                settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []), order: 0, isSelected: true)]
        } else if caseName.hasPrefix("long-") {
            let index = try XCTUnwrap(Int(caseName.dropFirst(5)))
            accounts = [try releasedPhrase(vectors("ios-386-long-phrases")[index], index: index)]
        } else if caseName == "multi" {
            for index in [9, 10, 11, 14] { accounts.append(try releasedPhrase(all[index], index: index)) }
        } else if caseName.hasPrefix("json-") || caseName.hasPrefix("seed-") {
            let index = try XCTUnwrap(Int(caseName.split(separator: "-").last ?? ""))
            let vector = all[index]
            let crypto = CryptoType(type: try XCTUnwrap(vector["cryptoType"] as? String).uppercased())
            let factory = SimulatorReleased386AccountOperationFactory(keystore: keys)
            let operation: BaseOperation<AccountItem>
            if caseName.hasPrefix("json-") {
                let data = try JSONSerialization.data(withJSONObject: XCTUnwrap(vector["exportedJSON"]))
                operation = factory.newAccountOperation(request: AccountImportKeystoreRequest(keystore: String(decoding: data, as: UTF8.self), password: try XCTUnwrap(vector["jsonPassword"] as? String), username: "Audit JSON", networkType: .sora, cryptoType: crypto))
            } else {
                operation = factory.newAccountOperation(request: AccountImportSeedRequest(seed: try XCTUnwrap(vector["seedHex"] as? String), username: "Audit seed", networkType: .sora, derivationPath: "", cryptoType: crypto))
            }
            operation.start()
            let account = try XCTUnwrap(operation.result).get()
            XCTAssertEqual(account.address, vector["address"] as? String)
            accounts = [account]
        } else {
            let index = caseName == "two-reinstalls" ? 12 : (caseName.hasPrefix("vector-") ? try XCTUnwrap(Int(caseName.dropFirst(7))) : 9)
            accounts = [try releasedPhrase(all[index], index: index)]
            if caseName == "model-v1" { version = .version1 }
        }
        if !accounts.isEmpty && expectedRoute != "legacy" && caseName != "fresh-import" {
            try writeRows(accounts, version: version)
            SettingsManager.shared.set(value: accounts[0], for: SettingsKey.selectedAccount.rawValue)
        }
        if !["pinless", "metadata-only", "erase-restore", "fresh-import"].contains(caseName) { try keys.saveKey(Data(pin.utf8), with: "pincode") }
        if caseName == "metadata-only" || caseName == "erase-restore" {
            for tag in try keys.allKeyIdentifiers() { try keys.deleteKey(for: tag) }
            expectedSigning = false
        }
        if ["bound-reinstall", "two-reinstalls", "preserved-return"].contains(caseName) {
            // The same manual current-PIN authorization as a normal first
            // unlock. This binding belongs to the proved row, before uninstall.
            _ = try WalletOwnerPIN(keystore: keys, settings: SettingsManager.shared)
                .authenticateCurrent(pin, accounts: accounts)
            if caseName == "preserved-return" {
                // Retained ownership survives a missing installation PIN. The
                // normal app must route to recovery, then require this owner
                // proof before returning the explicitly preserved generation.
                try keys.deleteKey(for: KeystoreTag.pincode.rawValue)
                expectedRoute = "recovery"
            }
        }
        if caseName == "new-phone" || caseName == "leftovers" {
            try UserStorageMigrator(targetVersion: .version2, storeURL: UserStorageParams.storageURL,
                modelDirectory: UserStorageParams.modelDirectory, keystore: keys,
                settings: SettingsManager.shared, fileManager: .default).performMigration()
            try WalletNetworkModelMigrator(keystore: keys, store: WalletNetworkStore(),
                settings: SettingsManager.shared).migrate(accounts: accounts, selectedAddress: accounts[0].address)
        }
        if caseName == "leftovers" {
            let journals = try WalletAccountCommitJournalStore()
            var commit = try journals.begin(walletId: "cnPublicPreviouslyAdded", existingWalletIds: accounts.map(\.address))
            for stage in [WalletAccountCommitStage.secretsPersisted, .coreDataCommitted, .networkModelActivated, .activated] {
                commit = try journals.advance(commit, to: stage)
            }
            _ = try Sora2PendingSubmissionStore().stage(account: accounts[0].address, hash: "0x" + String(repeating: "ab", count: 32))
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let safety = UserStorageParams.storageDirectoryURL.appendingPathComponent("WalletMigrationSafety")
            let attempt = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: safety, includingPropertiesForKeys: nil).first)
            let folders = [support.appendingPathComponent("SORA/WalletNetworks"),
                support.appendingPathComponent("SORA/WalletAccountCommits"),
                support.appendingPathComponent("SORA/PendingTransactions"), attempt]
            for folder in folders {
                for (prefix, suffix) in [(".durable-", ".tmp"), (".durable-rollback-", ".anchor"),
                                         (".durable-rollback-", ".safety-anchor"), (".durable-failed-", ".withdrawn")] {
                    let helper = folder.appendingPathComponent(prefix + UUID().uuidString + suffix)
                    try Data("public interrupted write".utf8).write(to: helper)
                    plantedHelpers.append(helper.path)
                }
            }
        }
        if caseName == "unreachable-node" {
            SettingsManager.shared.lastSuccessfulUrl = URL(string: "wss://127.0.0.1:1")
        }
        if ["reinstall", "bound-reinstall", "missing-db", "new-phone"].contains(caseName) {
            try FileManager.default.removeItem(at: UserStorageParams.storageDirectoryURL)
            expectedRows = caseName == "bound-reinstall"
            expectedSigning = caseName == "bound-reinstall"
            expectedRoute = "welcome"
            if caseName == "reinstall" || caseName == "bound-reinstall" { SettingsManager.shared.removeAll() }
            if caseName == "new-phone" {
                for tag in try keys.allKeyIdentifiers() { try keys.deleteKey(for: tag) }
                expectedRoute = "onboarding"
            }
        }
        if caseName == "pinless" { expectedRoute = "recovery" }
        if caseName == "corrupt-db" {
            try FileManager.default.removeItem(at: UserStorageParams.storageDirectoryURL)
            try FileManager.default.createDirectory(at: UserStorageParams.storageDirectoryURL, withIntermediateDirectories: true)
            try Data("public corrupt database fixture".utf8).write(to: UserStorageParams.storageURL)
            expectedRows = false
            expectedSigning = false
            expectedRoute = "recovery"
        }
        // For two real uninstalls, the original app PIN is expected to change;
        // the complete original wallet A material and its owner binding are not.
        let originalTags: [String]
        if caseName == "two-reinstalls" {
            let address = try XCTUnwrap(accounts.first).address
            originalTags = cryptoTags(address) + [address + WalletOwnerPIN.bindingSuffix]
        } else if caseName == "preserved-return" {
            // Owner-authorized return deliberately rotates ownership to the
            // newly chosen app PIN. All original cryptographic bytes remain.
            originalTags = try keys.allKeyIdentifiers().filter { !$0.hasSuffix(WalletOwnerPIN.bindingSuffix) }
        } else {
            originalTags = try keys.allKeyIdentifiers()
        }
        let hashes = try keyHashes(originalTags)
        let expectedAccounts = caseName == "two-reinstalls" ? [try expectedImportedAccount(all[9])] : accounts
        if caseName == "two-reinstalls" { expectedRoute = "welcome" }
        let accountsJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(expectedAccounts))
        var receipt: [String: Any] = ["case": caseName, "scope": "simulator-source-qualification", "releaseAuthorized": false,
            "expectedRoute": expectedRoute, "expectedSigning": expectedSigning, "expectedRows": expectedRows,
            "originalKeySHA256": hashes, "accounts": accountsJSON, "plantedHelpers": plantedHelpers,
            "historicalWriter": "354f176c", "publicFixturePIN": pin]
        if caseName == "two-reinstalls" {
            receipt["originalAccounts"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(accounts))
            receipt["newPublicFixturePIN"] = replacementPIN
        }
        if caseName == "erase-restore" {
            receipt["restoreScope"] = "simulator filesystem app-data restore; not physical iCloud or device-only Keychain migration"
            XCTAssertTrue(try keys.allKeyIdentifiers().isEmpty)
        }
        try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys]).write(to: receiptURL, options: .atomic)
        print("SIMULATOR_FIXTURE_PREPARED \(caseName) \(expectedRoute)")
    }

    func testVerifyStateAfterNormalApplicationLaunch() throws {
        var receipt = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: receiptURL)) as? [String: Any])
        XCTAssertEqual(receipt["case"] as? String, caseName)
        for path in receipt["plantedHelpers"] as? [String] ?? [] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: path), "Leftover was not swept: \(path)")
        }
        let hashes = try XCTUnwrap(receipt["originalKeySHA256"] as? [String: String])
        for (tag, expected) in hashes {
            // A successful retained-wallet adoption deliberately publishes a
            // newly salted binding to the manually supplied app PIN. Wallet
            // secrets must remain byte-identical; prove the new binding below.
            if caseName == "bound-reinstall" && tag.hasSuffix(WalletOwnerPIN.bindingSuffix) { continue }
            XCTAssertEqual(Data(SHA256.hash(data: try keys.fetchKey(for: tag))).map { String(format: "%02x", $0) }.joined(), expected, "Retained fixture changed: \(tag)")
        }
        let expected = try JSONDecoder().decode([AccountItem].self, from: JSONSerialization.data(withJSONObject: XCTUnwrap(receipt["accounts"])))
        if caseName == "bound-reinstall" {
            let grant = try WalletOwnerPIN(keystore: keys, settings: SettingsManager.shared)
                .authorizeRetained(pin, addresses: Set(expected.map(\.address)))
            XCTAssertEqual(grant.addresses, Set(expected.map(\.address)))
        }
        if caseName == "two-reinstalls" {
            let originals = try JSONDecoder().decode([AccountItem].self,
                from: JSONSerialization.data(withJSONObject: XCTUnwrap(receipt["originalAccounts"])))
            let original = try XCTUnwrap(originals.first)
            let imported = try XCTUnwrap(expected.first)
            XCTAssertNotEqual(original.address, imported.address)
            XCTAssertEqual(try keys.fetchKey(for: KeystoreTag.pincode.rawValue), Data(replacementPIN.utf8))
            let owner = WalletOwnerPIN(keystore: keys, settings: SettingsManager.shared)
            // UI restoration of B legitimately counts as a failed attempt for
            // A. Authenticate A before intentional negative probes, then leave
            // its durable counter reset through a real successful owner proof.
            XCTAssertEqual(try owner.authorizeRetained(pin, addresses: [original.address]).addresses, [original.address])
            XCTAssertThrowsError(try owner.authorizeRetained(replacementPIN, addresses: [original.address])) { error in
                guard case WalletRetainedPinGate.Failure.incorrectPin = error else {
                    return XCTFail("Expected a rejected PIN, not an unrelated failure: \(error)")
                }
            }
            XCTAssertEqual(try owner.authorizeRetained(replacementPIN, addresses: [original.address, imported.address]).addresses,
                [imported.address])
            XCTAssertEqual(try owner.authorizeRetained(pin, addresses: [original.address]).addresses, [original.address])
            XCTAssertEqual(try keyHashes(Array(hashes.keys)), hashes, "Original A keys and owner binding must stay byte-identical")
            if phase == "first-install" {
                receipt["postFirstImportKeySHA256"] = try cryptoState(imported.address)
                try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
                    .write(to: receiptURL, options: .atomic)
            } else {
                XCTAssertEqual(phase, "second-install")
                let importedHashes = try XCTUnwrap(receipt["postFirstImportKeySHA256"] as? [String: String])
                XCTAssertEqual(try cryptoState(imported.address), importedHashes,
                    "The second actual uninstall must preserve B's cryptographic bytes too")
            }
        }
        if caseName == "preserved-return" {
            XCTAssertEqual(try keys.fetchKey(for: KeystoreTag.pincode.rawValue), Data(replacementPIN.utf8))
            let addresses = Set(expected.map(\.address))
            let owner = WalletOwnerPIN(keystore: keys, settings: SettingsManager.shared)
            XCTAssertEqual(try owner.authorizeRetained(replacementPIN, addresses: addresses).addresses, addresses)
            XCTAssertThrowsError(try owner.authorizeRetained(pin, addresses: addresses))
            XCTAssertEqual(try owner.authorizeRetained(replacementPIN, addresses: addresses).addresses, addresses)
            let paths = try WalletLocalStateSetAside.Paths.production()
            let folders = try FileManager.default.contentsOfDirectory(at: paths.setAsideRootURL,
                includingPropertiesForKeys: nil).filter {
                    FileManager.default.fileExists(atPath: $0.appendingPathComponent(WalletPreservedGeneration.manifestName).path)
                }
            XCTAssertEqual(folders.count, 1, "The normal Set up again flow must preserve a verifiable generation")
            let manifest = try JSONDecoder().decode(WalletPreservedGeneration.Manifest.self,
                from: Data(contentsOf: XCTUnwrap(folders.first).appendingPathComponent(WalletPreservedGeneration.manifestName)))
            XCTAssertTrue(manifest.entries.contains { $0.path == "CoreData/" + UserStorageParams.storageURL.lastPathComponent })
            XCTAssertFalse(FileManager.default.fileExists(atPath: paths.setAsideRootURL.appendingPathComponent(WalletPreservedGeneration.returnName).path))
            XCTAssertFalse(try keys.allKeyIdentifiers().contains { $0.hasPrefix("wallet.preservedReturn.") })
            XCTAssertTrue(WalletPreservedGeneration.available(paths: paths, settings: SettingsManager.shared).isEmpty)
            receipt["returnedGeneration"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(manifest))
            receipt["newPublicFixturePIN"] = replacementPIN
            try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
                .write(to: receiptURL, options: .atomic)
        }
        if receipt["expectedRows"] as? Bool == true {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try model(.version2))
            let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                at: UserStorageParams.storageURL, options: [NSReadOnlyPersistentStoreOption: true])
            defer { try? coordinator.remove(store) }
            let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator
            let actual = try context.performAndWait { try context.fetch(NSFetchRequest<CDAccountItem>(entityName: "CDAccountItem")).map { try AccountItemMapper().transform(entity: $0) } }
            XCTAssertEqual(Set(actual.map(\.address)), Set(expected.map(\.address)))
            XCTAssertEqual(actual.filter(\.isSelected).map(\.address), expected.first.map { [$0.address] } ?? [])
            for account in actual {
                if caseName == "preserved-return" {
                    XCTAssertEqual(account.username, expected.first { $0.address == account.address }?.username)
                    XCTAssertEqual(account.publicKeyData, expected.first { $0.address == account.address }?.publicKeyData)
                }
                if caseName == "pinless" {
                    XCTAssertTrue(SettingsManager.shared.walletMigrationRecoveryRequired)
                    XCTAssertFalse(try keys.checkKey(for: KeystoreTag.pincode.rawValue))
                    XCTAssertFalse(try keys.checkKey(for: account.address + WalletOwnerPIN.bindingSuffix))
                    XCTAssertThrowsError(try WalletRecoveryCapabilityGate.shared.requireMutableWalletAccess())
                    let secret = try XCTUnwrap(keys.fetchSecretKeyForAddress(account.address))
                    XCTAssertThrowsError(try LegacySoraIdentityValidator.validateSigningSecret(address: account.address,
                        publicKey: account.publicKeyData, cryptoType: account.cryptoType,
                        networkType: account.networkType, secret: secret, recoveryGate: .shared))
                    continue
                }
                if receipt["expectedSigning"] as? Bool == true {
                    var secret = try XCTUnwrap(keys.fetchSecretKeyForAddress(account.address))
                    defer { secret.resetBytes(in: secret.startIndex..<secret.endIndex) }
                    try LegacySoraIdentityValidator.validateSigningSecret(address: account.address,
                        publicKey: account.publicKeyData, cryptoType: account.cryptoType,
                        networkType: account.networkType, secret: secret, recoveryGate: .shared)
                    var material = try WalletBackupMaterial.load(for: account, keystore: keys)
                    defer { material.wipe() }
                    if let entropy = try keys.fetchEntropyForAddress(account.address), WalletMnemonicWordPolicy.isDerivableEntropy(entropy) {
                        XCTAssertEqual(material.phraseStatus, .matching)
                    }
                    XCTAssertEqual(try SimulatorReleased386AccountItemMapper().transform(entity: context.performAndWait { try XCTUnwrap(context.fetch(NSFetchRequest<CDAccountItem>(entityName: "CDAccountItem")).first { $0.identifier == account.address }) }).address, account.address)
                } else {
                    XCTAssertFalse(try keys.hasScopedSigningMaterial(for: account.address))
                }
            }
            let oldRows = try context.performAndWait {
                try context.fetch(NSFetchRequest<CDAccountItem>(entityName: "CDAccountItem")).map {
                    try SimulatorReleased386AccountItemMapper().transform(entity: $0)
                }
            }
            try SimulatorReleased386Startup.verify(accounts: oldRows, keys: keys,
                canSign: receipt["expectedSigning"] as? Bool == true)
            XCTAssertEqual(SettingsManager.shared.walletMigrationRecoveryRequired, caseName == "pinless")
        }
        print("SIMULATOR_FIXTURE_VERIFIED \(caseName): original key bytes, public identity, phrase/signing capability where applicable")
    }
}

// The two method bodies below are copied byte-for-byte from 354f176c.
// The adapters make their external dependencies explicit and keep all old
// deletion behavior confined to an in-memory copy of this public fixture.
private enum SimulatorReleased386Startup {
    final class Selection { let currentAccount: AccountItem?; init(_ value: AccountItem?) { currentAccount = value } }
    struct Namespace { let shared: Selection }
    final class Settings {
        // 354f176c SettingsExtension reads SelectedWalletSettings.hasValue,
        // an in-memory DB selection. Clearing UserDefaults does not clear it.
        let hasSelectedAccount: Bool
        private(set) var wiped = false
        init(_ selected: AccountItem?) { hasSelectedAccount = selected != nil }
        func removeAll() { wiped = true }
    }
    final class Presenter {
        var outcome = "undecided"
        func didDecideOnboarding() { outcome = "onboarding" }
        func didDecideLocalAuthentication() { outcome = "pin" }
        func didDecidePincodeSetup() { outcome = "setup" }
        func didDecideBroken() { outcome = "broken" }
    }
    final class Inconsistent {
        let settings: Settings
        let keychain: KeystoreProtocol
        let SelectedWalletSettings: Namespace
        init(settings: Settings, keys: KeystoreProtocol, selected: AccountItem?) {
            self.settings = settings; keychain = keys
            SelectedWalletSettings = Namespace(shared: Selection(selected))
        }
    func migrate() throws {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
            return
        }

        let hasSecretKey = try keychain.checkSecretKeyForAddress(selectedAccount.address)

        if !hasSecretKey {
            settings.removeAll()
        }
    }
    }
    final class Routing {
        let settings: Settings
        let keystore: KeystoreProtocol
        let presenter: Presenter?
        init(settings: Settings, keys: KeystoreProtocol, presenter: Presenter) {
            self.settings = settings; keystore = keys; self.presenter = presenter
        }
    func decideModuleSynchroniously() {
        do {
            if !settings.hasSelectedAccount {
                try keystore.deleteKeyIfExists(for: KeystoreTag.pincode.rawValue)

                presenter?.didDecideOnboarding()
                return
            } else {
                try? keystore.deleteKeyIfExists(for: KeystoreTag.legacyEntropy.rawValue)
            }

            let pincodeExists = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)

            if pincodeExists {
                presenter?.didDecideLocalAuthentication()
            } else {
                presenter?.didDecidePincodeSetup()
            }

        } catch {
            presenter?.didDecideBroken()
        }
    }
    }
    static func verify(accounts: [AccountItem], keys: KeystoreProtocol, canSign: Bool) throws {
        let clone = InMemoryKeychain()
        for tag in try keys.allKeyIdentifiers() { try clone.addKey(keys.fetchKey(for: tag), with: tag) }
        let selected = accounts.first(where: \.isSelected)
        let settings = Settings(selected)
        try Inconsistent(settings: settings, keys: clone, selected: selected).migrate()
        let expectedPreferenceWipe = try selected.map { try !keys.checkSecretKeyForAddress($0.address) } ?? false
        XCTAssertEqual(settings.wiped, expectedPreferenceWipe)
        // Missing-key fixtures deliberately expose the old preference wipe.
        // Their PIN route alone is not evidence of signing or a safe downgrade.
        let presenter = Presenter()
        Routing(settings: settings, keys: clone, presenter: presenter).decideModuleSynchroniously()
        XCTAssertEqual(presenter.outcome, try clone.checkKey(for: KeystoreTag.pincode.rawValue) ? "pin" : "setup")
        // This independent clone verifies old reader/key preservation, not
        // permission to sign in the new app while its recovery marker is set.
        let oldVerificationGate = WalletRecoveryCapabilityGate(settings: InMemorySettingsManager(),
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false },
            credentialRepairPending: { false })
        if canSign {
            XCTAssertFalse(settings.wiped)
            for account in accounts {
                let secret = try XCTUnwrap(clone.fetchSecretKeyForAddress(account.address))
                XCTAssertEqual(secret, try keys.fetchSecretKeyForAddress(account.address))
                try LegacySoraIdentityValidator.validateSigningSecret(address: account.address,
                    publicKey: account.publicKeyData, cryptoType: account.cryptoType,
                    networkType: account.networkType, secret: secret, recoveryGate: oldVerificationGate)
            }
        }
    }
}
