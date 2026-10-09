// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CoreData
import CryptoKit
import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFUtils
import XCTest
@testable import SoraPassport

/// An explicitly invoked, disposable simulator rehearsal. The writer comes
/// from a release tag; this is not an original App Store binary or a physical
/// device qualification receipt. Each phase runs in a separate test process.
final class HistoricalReleaseUpgradeTests: XCTestCase {
    private struct Baseline: Codable {
        let runID: String
        let accounts: [AccountItem]
        let selectedAddress: String
        let keyDigests: [String: String]
    }

    private var rehearsalDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HistoricalWriterUpgradeRehearsal", isDirectory: true)
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func testPersistentUpgrade() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Historical writer rehearsal requires its dedicated disposable simulator")
        #else
        let environment = ProcessInfo.processInfo.environment
        guard let phase = environment["SORA_HISTORICAL_WRITER_PHASE"] else {
            throw XCTSkip("Run the historical-writer script for the three persistent phases")
        }
        let runID = try XCTUnwrap(environment["SORA_HISTORICAL_WRITER_RUN_ID"])
        XCTAssertNotNil(UUID(uuidString: runID))
        guard UUID(uuidString: runID) != nil,
              ProcessInfo.processInfo.arguments.contains("-UNITTEST") else {
            throw NSError(domain: "HistoricalWriterRehearsal", code: 1)
        }
        switch phase {
        case "produce": try produce(runID: runID)
        case "migrate": try migrateAndSign(runID: runID, isRestart: false)
        case "restart": try migrateAndSign(runID: runID, isRestart: true)
        default: XCTFail("Unknown historical writer phase")
        }
        #endif
    }

    private func produce(runID: String) throws {
        let manager = FileManager.default
        // Refuse to overwrite existing app data. The runner owns a fresh
        // simulator; an existing wallet or prior run is never treated as empty.
        guard !manager.fileExists(atPath: rehearsalDirectory.path),
              !manager.fileExists(atPath: UserStorageParams.storageURL.path),
              try Keychain().allKeyIdentifiers().isEmpty else {
            throw NSError(domain: "HistoricalWriterRehearsal", code: 2)
        }
        try manager.createDirectory(at: rehearsalDirectory,
                                    withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        let keychain = Keychain()
        let factory = HistoricalReleaseAccountOperationFactory(keystore: keychain)
        var accounts: [AccountItem] = []
        for entropyCount in [16, 20, 24, 28, 32] {
            for cryptoType in [CryptoType.sr25519, .ed25519, .ecdsa] {
                let mnemonic = try IRMnemonicCreator(language: .english)
                    .mnemonic(fromEntropy: Data(repeating: UInt8(entropyCount), count: entropyCount))
                let request = AccountCreationRequest(
                    username: "Historical \(entropyCount * 3 / 4)-word \(cryptoType)",
                    type: .sora,
                    derivationPath: "//legacy//7///retained-password",
                    cryptoType: cryptoType
                )
                let account = try execute(factory.newAccountOperation(request: request, mnemonic: mnemonic))
                accounts.append(ordered(account, index: accounts.count))
            }
        }
        for cryptoType in [CryptoType.sr25519, .ed25519, .ecdsa] {
            let request = AccountImportSeedRequest(
                seed: Data(repeating: 101, count: 32).toHex(),
                username: "Historical raw seed \(cryptoType)",
                networkType: .sora,
                derivationPath: "//legacy//3",
                cryptoType: cryptoType
            )
            accounts.append(ordered(try execute(factory.newAccountOperation(request: request)),
                                    index: accounts.count))
        }
        // Generate disposable JSON inputs separately. Only the historical
        // importer writes their secrets into the persistent simulator Keychain.
        for cryptoType in [CryptoType.sr25519, .ed25519, .ecdsa] {
            let inputKeys = InMemoryKeychain()
            let inputFactory = HistoricalReleaseAccountOperationFactory(keystore: inputKeys)
            let inputAccount = try execute(inputFactory.newAccountOperation(request:
                AccountImportSeedRequest(
                    seed: Data(repeating: 102, count: 32).toHex(),
                    username: "Disposable JSON input",
                    networkType: .sora, derivationPath: "", cryptoType: cryptoType
                )))
            let json = try KeystoreExportWrapper(keystore: inputKeys)
                .export(account: inputAccount, password: "disposable-rehearsal")
            let request = AccountImportKeystoreRequest(
                keystore: try XCTUnwrap(String(data: json, encoding: .utf8)),
                password: "disposable-rehearsal",
                username: "Historical JSON \(cryptoType)",
                networkType: .sora, cryptoType: cryptoType
            )
            accounts.append(ordered(try execute(factory.newAccountOperation(request: request)),
                                    index: accounts.count))
        }
        XCTAssertEqual(accounts.count, 21)
        XCTAssertEqual(Set(accounts.map(\.address)).count, 21)
        let selectedAddress = accounts[7].address
        accounts = accounts.map { $0.replacingSelection($0.address == selectedAddress) }
        try writeHistoricalDatabase(accounts)
        SettingsManager.shared.set(value: accounts[7], for: SettingsKey.selectedAccount.rawValue)
        let baseline = Baseline(runID: runID, accounts: accounts,
                                selectedAddress: selectedAddress,
                                keyDigests: try currentKeyDigests())
        try persist(JSONEncoder().encode(baseline), name: "baseline.json")
        XCTAssertEqual(try readDatabase(), accounts)
        XCTAssertFalse(SettingsManager.shared.walletMigrationRecoveryRequired)
        try persist(Data("produced".utf8), name: "producer-completed")
    }

    private func ordered(_ account: AccountItem, index: Int) -> AccountItem {
        AccountItem(address: account.address, cryptoType: account.cryptoType,
                    networkType: account.networkType, username: account.username,
                    publicKeyData: account.publicKeyData,
                    settings: AccountSettings(visibleAssetIds: ["legacy-visible-\(index)"],
                                              orderedAssetIds: ["legacy-visible-\(index)"]),
                    order: Int16(index), isSelected: false)
    }

    private func execute<T>(_ operation: BaseOperation<T>) throws -> T {
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }

    private func persist(_ data: Data, name: String) throws {
        let url = rehearsalDirectory.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func model() throws -> NSManagedObjectModel {
        let name = UserStorageVersion.version2.rawValue
        let url = Bundle.main.url(forResource: name, withExtension: "omo",
                                  subdirectory: UserStorageParams.modelDirectory)
            ?? Bundle.main.url(forResource: name, withExtension: "mom",
                                subdirectory: UserStorageParams.modelDirectory)
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: XCTUnwrap(url)))
    }

    private func writeHistoricalDatabase(_ accounts: [AccountItem]) throws {
        try FileManager.default.createDirectory(at: UserStorageParams.storageDirectoryURL,
                                                withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try model())
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                                       configurationName: nil,
                                                       at: UserStorageParams.storageURL,
                                                       options: nil)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            let mapper = AccountItemMapper() // Byte-identical to the pinned release.
            for account in accounts {
                let entity = CDAccountItem(context: context)
                try mapper.populate(entity: entity, from: account, using: context)
            }
            try context.save()
        }
        try coordinator.remove(store)
    }

    private func readDatabase() throws -> [AccountItem] {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try model())
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                                       configurationName: nil,
                                                       at: UserStorageParams.storageURL,
                                                       options: [NSReadOnlyPersistentStoreOption: true])
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return try context.performAndWait {
            let request = NSFetchRequest<CDAccountItem>(entityName: "CDAccountItem")
            request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
            return try context.fetch(request).map { try AccountItemMapper().transform(entity: $0) }
        }
    }

    private func currentKeyDigests() throws -> [String: String] {
        let keychain = Keychain()
        return try Dictionary(uniqueKeysWithValues: keychain.allKeyIdentifiers().map {
            ($0, digest(try keychain.fetchKey(for: $0)))
        })
    }

    private func complete<T>(_ work: (@escaping (Result<T, Error>) -> Void) -> Void) throws -> T {
        let completed = expectation(description: "Wallet persistence operation completed")
        var result: Result<T, Error>?
        work { value in result = value; completed.fulfill() }
        wait(for: [completed], timeout: 30)
        return try XCTUnwrap(result).get()
    }

    private func migrateAndSign(runID: String, isRestart: Bool) throws {
        let baseline = try JSONDecoder().decode(Baseline.self,
            from: Data(contentsOf: rehearsalDirectory.appendingPathComponent("baseline.json")))
        XCTAssertEqual(baseline.runID, runID)
        guard baseline.runID == runID else {
            throw NSError(domain: "HistoricalWriterRehearsal", code: 3)
        }
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: rehearsalDirectory.appendingPathComponent("producer-completed").path))
        XCTAssertEqual(try currentKeyDigests(), baseline.keyDigests)
        XCTAssertEqual(try readDatabase(), baseline.accounts)
        let oldGraph: WalletNetworkSnapshot? = isRestart
            ? try JSONDecoder().decode(WalletNetworkSnapshot.self,
                from: Data(contentsOf: rehearsalDirectory.appendingPathComponent("migrated-graph.json")))
            : nil
        let keychain = Keychain()
        let databaseMigrator = UserStorageMigrator(
            targetVersion: .version2, storeURL: UserStorageParams.storageURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keychain, settings: SettingsManager.shared, fileManager: .default
        )
        try databaseMigrator.performMigration()
        let graphStore = try WalletNetworkStore()
        try WalletNetworkModelMigrator(keystore: keychain, store: graphStore,
                                       settings: SettingsManager.shared)
            .migrate(accounts: baseline.accounts, selectedAddress: baseline.selectedAddress)
        let graph = try XCTUnwrap(graphStore.load())
        XCTAssertEqual(graph.wallets.count, 21)
        XCTAssertEqual(graph.selectedWalletId, baseline.selectedAddress)
        for account in baseline.accounts {
            let children = graph.accounts.filter { $0.walletId == account.address }
            XCTAssertEqual(children.first { $0.networkId == .sora2 }?.publicKey, account.publicKeyData)
            XCTAssertEqual(children.first { $0.networkId == .sora2 }?.address, account.address)
            let entropy = try keychain.fetchEntropyForAddress(account.address)
            let supportsNexus = entropy.map { [16, 32].contains($0.count) } ?? false
            XCTAssertEqual(children.count, supportsNexus
                ? 1 + NexusNetworkAdmissionPolicy.current.admittedDerivationProfiles.count : 1)
        }
        if let oldGraph { XCTAssertEqual(graph, oldGraph) }
        let selected: AccountItem? = try complete {
            SelectedWalletSettings.shared.setup(runningCompletionIn: nil, completionClosure: $0)
        }
        XCTAssertEqual(selected?.address, baseline.selectedAddress)
        let challenge = Data("SORA disposable historical-writer upgrade proof v1".utf8)
        for account in baseline.accounts {
            let selected: AccountItem = try complete {
                SelectedWalletSettings.shared.save(value: account,
                    runningCompletionIn: nil, completionClosure: $0)
            }
            XCTAssertEqual(selected.address, account.address)
            // Exercise the full production selection/lifecycle/identity gate,
            // not only raw crypto primitives. sign() also verifies the result.
            let signature = try SigningWrapper(keystore: keychain, account: selected).sign(challenge)
            XCTAssertFalse(signature.rawData().isEmpty)
        }
        let restored: AccountItem = try complete {
            SelectedWalletSettings.shared.save(value: baseline.accounts[7],
                runningCompletionIn: nil, completionClosure: $0)
        }
        XCTAssertEqual(restored.address, baseline.selectedAddress)
        XCTAssertEqual(try readDatabase(), baseline.accounts)
        XCTAssertEqual(try currentKeyDigests(), baseline.keyDigests)
        let finalGraph = try XCTUnwrap(graphStore.load())
        // Account selection records its own timestamp. Switching away and
        // back must preserve every identity and restore the selected wallet.
        XCTAssertEqual(finalGraph.schemaVersion, graph.schemaVersion)
        XCTAssertEqual(finalGraph.selectedWalletId, graph.selectedWalletId)
        XCTAssertEqual(finalGraph.wallets, graph.wallets)
        XCTAssertEqual(finalGraph.accounts, graph.accounts)
        XCTAssertFalse(SettingsManager.shared.walletMigrationRecoveryRequired)
        if !isRestart {
            try persist(JSONEncoder().encode(finalGraph), name: "migrated-graph.json")
        }
        let observation: [String: Any] = [
            "phase": isRestart ? "restart" : "migrate", "runID": runID,
            "accountsPreserved": baseline.accounts.count, "signaturesVerified": 21,
            "keyRecordsPreserved": baseline.keyDigests.count,
            "networkIdentities": graph.accounts.count,
            "physicalDeviceQualification": false, "productionAuthorization": false
        ]
        try persist(JSONSerialization.data(withJSONObject: observation, options: [.prettyPrinted, .sortedKeys]),
                    name: isRestart ? "restart-observation.json" : "migration-observation.json")
    }
}
