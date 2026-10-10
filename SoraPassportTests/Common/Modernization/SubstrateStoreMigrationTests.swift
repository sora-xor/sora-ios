// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CoreData
import Foundation
import RobinHood
import XCTest
@testable import SoraPassport

/// App Store 3.8.6 added `CDConfig`, `CDMetadataVersion` and `CDNode` to
/// `SubstrateDataModel`. Earlier 3.9.0 builds had the 10-entity model and opened
/// the store with `.removeStore`, so updating from 3.8.6 deleted contacts, node
/// choices and pool favourites. These tests write stores with the shipped
/// models and open them through the production configuration.
final class SubstrateStoreMigrationTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubstrateStoreMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            _ = try? FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: storeURL.path
            )
            try? FileManager.default.removeItem(at: directory)
        }
    }

    // MARK: - Models

    private var storeURL: URL { directory.appendingPathComponent("SubstrateDataModel.sqlite") }

    private var appModelURL: URL {
        Bundle.main.url(forResource: "SubstrateDataModel", withExtension: "momd")!
    }

    private func bundledVersion(_ name: String) throws -> NSManagedObjectModel {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: name, withExtension: "mom", subdirectory: "SubstrateDataModel.momd"),
            "missing \(name).mom in SubstrateDataModel.momd"
        )
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: url))
    }

    /// `SubstrateDataModel.xcdatamodel/contents` at App Store 3.8.6 (`354f176c`),
    /// compiled independently of the project with
    /// `xcrun momc SubstrateDataModel386.xcdatamodel out.mom` (Xcode 27.0;
    /// SHA-256 783a24c8608d216f8016733978405439b8264215364183cc9c1cae41b02f15b3).
    /// It guards the v2 model: if v2 ever differs from 3.8.6, the tests below fail.
    private func appStore386Model() throws -> NSManagedObjectModel {
        let data = try XCTUnwrap(Data(base64Encoded: Self.appStore386ModelBase64.joined()))
        let url = directory.appendingPathComponent("SubstrateDataModel386.mom")
        try data.write(to: url)
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: url))
    }

    private func unrelatedModel() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = "CDSomethingElse"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        let attribute = NSAttributeDescription()
        attribute.name = "value"
        attribute.attributeType = .stringAttributeType
        attribute.isOptional = true
        entity.properties = [attribute]
        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }

    // MARK: - Fixtures

    private struct Seed {
        static let chainId = "7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5"
        static let contactAddress = "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm"
        static let defaultNode = URL(string: "wss://ws.mof.sora.org")!
        static let customNode = URL(string: "wss://my-own-node.example")!
        static let poolId = "pool-xor-val"
    }

    /// Writes the user data that the 3.8.6 store holds, with that model.
    private func writeStore(model: NSManagedObjectModel, includes386Entities: Bool) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        var saveError: Error?
        context.performAndWait {
            let contact = NSEntityDescription.insertNewObject(forEntityName: "CDContactItem", into: context)
            contact.setValue("contact-1", forKey: "identifier")
            contact.setValue(Seed.contactAddress, forKey: "peerAddress")
            contact.setValue("Alice", forKey: "peerName")
            contact.setValue(Seed.contactAddress, forKey: "targetAddress")
            contact.setValue(Int64(1_700_000_000), forKey: "updatedAt")

            let defaultNode = NSEntityDescription.insertNewObject(forEntityName: "CDChainNode", into: context)
            defaultNode.setValue("SORA Ministry of Finance", forKey: "name")
            defaultNode.setValue(Seed.defaultNode, forKey: "url")
            let customNode = NSEntityDescription.insertNewObject(forEntityName: "CDChainNode", into: context)
            customNode.setValue("My node", forKey: "name")
            customNode.setValue(Seed.customNode, forKey: "url")

            let chain = NSEntityDescription.insertNewObject(forEntityName: "CDChain", into: context)
            chain.setValue(Seed.chainId, forKey: "chainId")
            chain.setValue("SORA", forKey: "name")
            chain.setValue(Int16(69), forKey: "addressPrefix")
            chain.setValue(NSSet(object: defaultNode), forKey: "nodes")
            chain.setValue(NSSet(object: customNode), forKey: "customNodes")
            chain.setValue(customNode, forKey: "selectedNode")

            let pool = NSEntityDescription.insertNewObject(forEntityName: "CDPoolInfo", into: context)
            pool.setValue(Seed.poolId, forKey: "poolId")
            pool.setValue(WalletAssetId.xor.rawValue, forKey: "baseAssetId")
            pool.setValue(WalletAssetId.val.rawValue, forKey: "targetAssetId")
            pool.setValue(false, forKey: "isFavorite")
            pool.setValue(Int64(3), forKey: "order")

            if includes386Entities {
                let node = NSEntityDescription.insertNewObject(forEntityName: "CDNode", into: context)
                node.setValue("Cached node", forKey: "name")
                node.setValue("wss://ws.mof.sora.org", forKey: "address")
                let config = NSEntityDescription.insertNewObject(forEntityName: "CDConfig", into: context)
                config.setValue("prod", forKey: "configId")
                config.setValue(NSSet(object: node), forKey: "nodes")
                let version = NSEntityDescription.insertNewObject(forEntityName: "CDMetadataVersion", into: context)
                version.setValue(Int32(133), forKey: "specVersion")
                version.setValue(Int32(131), forKey: "transactionVersion")
            }

            do {
                try context.save()
            } catch {
                saveError = error
            }
        }
        if let saveError { throw saveError }
        try coordinator.remove(store)
    }

    private func open(_ configuration: CoreDataServiceConfiguration) -> CoreDataService {
        CoreDataService(configuration: configuration)
    }

    private func fetch(
        _ entityName: String,
        in service: CoreDataService,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [NSManagedObject] {
        let expectation = expectation(description: "fetch \(entityName)")
        var objects: [NSManagedObject] = []
        service.performAsync { context, error in
            XCTAssertNil(error, file: file, line: line)
            context?.performAndWait {
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                objects = (try? context?.fetch(request)) ?? []
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
        return objects
    }

    private func assertUserDataSurvived(
        in service: CoreDataService,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        var contactAddress: String?
        var poolFavourite: Bool?
        var chain: ChainModel?
        let expectation = expectation(description: "read user data")
        service.performAsync { context, error in
            XCTAssertNil(error, file: file, line: line)
            context?.performAndWait {
                let contacts = (try? context?.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDContactItem"))) ?? []
                contactAddress = contacts.first?.value(forKey: "peerAddress") as? String
                let pools = (try? context?.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDPoolInfo"))) ?? []
                poolFavourite = pools.first?.value(forKey: "isFavorite") as? Bool
                if let entity = (try? context?.fetch(NSFetchRequest<CDChain>(entityName: "CDChain")))?.first {
                    chain = try? ChainModelMapper().transform(entity: entity)
                }
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)

        XCTAssertEqual(contactAddress, Seed.contactAddress, "contact lost", file: file, line: line)
        XCTAssertEqual(poolFavourite, false, "pool favourite lost", file: file, line: line)
        let model = try XCTUnwrap(chain, "chain row lost", file: file, line: line)
        XCTAssertEqual(model.chainId, Seed.chainId, file: file, line: line)
        XCTAssertEqual(model.selectedNode?.url, Seed.customNode, "selected node lost", file: file, line: line)
        XCTAssertEqual(model.customNodes?.map(\.url), [Seed.customNode], "custom node lost", file: file, line: line)
        XCTAssertEqual(model.nodes.map(\.url), [Seed.defaultNode], file: file, line: line)
    }

    private func storeOpens(with model: NSManagedObjectModel) -> Bool {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        guard let store = try? coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        ) else {
            return false
        }
        try? coordinator.remove(store)
        return true
    }

    private func isPersistent(_ configuration: CoreDataServiceConfiguration) -> Bool {
        if case .persistent = configuration.storageType { return true }
        return false
    }

    // MARK: - Tests

    func testCurrentModelIsAnExactCopyOfAppStore386() throws {
        let current = try XCTUnwrap(NSManagedObjectModel(contentsOf: appModelURL))
        let appStore386 = try appStore386Model()
        XCTAssertEqual(
            current.entityVersionHashesByName,
            appStore386.entityVersionHashesByName,
            "SubstrateDataModel 2 must stay identical to App Store 3.8.6 so either app can open the other's store"
        )
        XCTAssertTrue(Set(current.entitiesByName.keys).isSuperset(of: ["CDConfig", "CDMetadataVersion", "CDNode"]))

        let v1 = try bundledVersion("SubstrateDataModel")
        XCTAssertEqual(v1.entities.count, 10)
        XCTAssertEqual(try bundledVersion("SubstrateDataModel 2").entityVersionHashesByName,
                       appStore386.entityVersionHashesByName)
    }

    func testAppStore386StoreKeepsContactsNodesAndPoolFavourites() throws {
        try writeStore(model: try appStore386Model(), includes386Entities: true)

        let setup = SubstrateDataStorageFacade.makeConfiguration(
            modelURL: appModelURL,
            databaseDirectory: directory,
            databaseName: storeURL.lastPathComponent
        )

        XCTAssertEqual(setup.preparation, .ready, "a 3.8.6 store needs no migration")
        XCTAssertTrue(isPersistent(setup.configuration))
        let service = open(setup.configuration)
        try assertUserDataSurvived(in: service)
        XCTAssertEqual(fetch("CDConfig", in: service).first?.value(forKey: "configId") as? String, "prod")
        XCTAssertEqual(fetch("CDMetadataVersion", in: service).count, 1)
        try service.close()

        // Downgrade: App Store 3.8.6 opens the store 3.9.0 used.
        XCTAssertTrue(storeOpens(with: try appStore386Model()))
    }

    func testEarlierModelStoreIsMigratedNotWiped() throws {
        try writeStore(model: try bundledVersion("SubstrateDataModel"), includes386Entities: false)

        let setup = SubstrateDataStorageFacade.makeConfiguration(
            modelURL: appModelURL,
            databaseDirectory: directory,
            databaseName: storeURL.lastPathComponent
        )

        XCTAssertEqual(setup.preparation, .migrated)
        let service = open(setup.configuration)
        try assertUserDataSurvived(in: service)
        XCTAssertTrue(fetch("CDConfig", in: service).isEmpty)
        try service.close()

        // The migrated store is in the 3.8.6 schema, so a downgrade keeps it too.
        XCTAssertTrue(storeOpens(with: try appStore386Model()))
        // A second launch has nothing to do.
        XCTAssertEqual(
            SubstrateStoreMigrator.prepare(storeURL: storeURL, modelURL: appModelURL, logger: nil),
            .ready
        )
    }

    func testStoreFromUnknownModelIsRemovedAndOtherStoresAreUntouched() throws {
        let userStore = directory.appendingPathComponent("UserDataModel.sqlite")
        let userStoreBytes = Data("wallet accounts live here".utf8)
        try userStoreBytes.write(to: userStore)

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: unrelatedModel())
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        try coordinator.remove(store)

        let setup = SubstrateDataStorageFacade.makeConfiguration(
            modelURL: appModelURL,
            databaseDirectory: directory,
            databaseName: storeURL.lastPathComponent
        )

        XCTAssertEqual(setup.preparation, .removedIncompatible)
        for suffix in ["", "-wal", "-shm"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path + suffix))
        }
        XCTAssertEqual(try Data(contentsOf: userStore), userStoreBytes)

        let service = open(setup.configuration)
        XCTAssertTrue(fetch("CDContactItem", in: service).isEmpty)
        try service.close()
    }

    func testFileThatIsNotADatabaseIsRemoved() throws {
        try Data(repeating: 0x5A, count: 4096).write(to: storeURL)

        XCTAssertEqual(
            SubstrateStoreMigrator.prepare(storeURL: storeURL, modelURL: appModelURL, logger: nil),
            .removedIncompatible
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testUnreadableStoreIsKeptAndThisSessionUsesMemory() throws {
        try writeStore(model: try bundledVersion("SubstrateDataModel"), includes386Entities: false)
        let before = try Data(contentsOf: storeURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: storeURL.path)

        let setup = SubstrateDataStorageFacade.makeConfiguration(
            modelURL: appModelURL,
            databaseDirectory: directory,
            databaseName: storeURL.lastPathComponent
        )

        XCTAssertEqual(setup.preparation, .deferred)
        XCTAssertFalse(isPersistent(setup.configuration), "this session must not touch the store")
        let service = open(setup.configuration)
        XCTAssertTrue(fetch("CDContactItem", in: service).isEmpty)
        try service.close()

        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: storeURL.path)
        XCTAssertEqual(try Data(contentsOf: storeURL), before)

        // Once the store is readable again, the next launch migrates it.
        let next = SubstrateDataStorageFacade.makeConfiguration(
            modelURL: appModelURL,
            databaseDirectory: directory,
            databaseName: storeURL.lastPathComponent
        )
        XCTAssertEqual(next.preparation, .migrated)
        let service2 = open(next.configuration)
        try assertUserDataSurvived(in: service2)
        try service2.close()
    }

    func testNoStoreYetIsReady() {
        XCTAssertEqual(
            SubstrateStoreMigrator.prepare(storeURL: storeURL, modelURL: appModelURL, logger: nil),
            .ready
        )
    }

    func testTransientErrorsAreRecognised() {
        func sqlite(_ code: Int) -> NSError {
            NSError(domain: NSCocoaErrorDomain, code: 134_180, userInfo: ["NSSQLiteErrorDomain": code])
        }
        XCTAssertTrue(SubstrateStoreMigrator.isTransient(sqlite(13)), "SQLITE_FULL")
        XCTAssertTrue(SubstrateStoreMigrator.isTransient(sqlite(266)), "SQLITE_IOERR_READ")
        XCTAssertTrue(SubstrateStoreMigrator.isTransient(sqlite(23)), "SQLITE_AUTH")
        XCTAssertFalse(SubstrateStoreMigrator.isTransient(sqlite(11)), "SQLITE_CORRUPT")
        XCTAssertFalse(SubstrateStoreMigrator.isTransient(sqlite(26)), "SQLITE_NOTADB")
        let nested = NSError(
            domain: NSCocoaErrorDomain,
            code: 134_110,
            userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))]
        )
        XCTAssertTrue(SubstrateStoreMigrator.isTransient(nested))
        XCTAssertFalse(SubstrateStoreMigrator.isTransient(NSError(domain: NSCocoaErrorDomain, code: 134_100)))
    }

    private static let appStore386ModelBase64: [String] = [
        "YnBsaXN0MDDUAAEAAgADAAQABQAGAAcAClgkdmVyc2lvblkkYXJjaGl2ZXJUJHRvcFgkb2JqZWN0cxIAAYagXxAPTlNLZXllZEFy",
        "Y2hpdmVy0QAIAAlUcm9vdIABrxDxAAsADAAZADkAOgA7ADwAPQA+AD8AQABBAEIAQwBEAEUARgBcAGAAZwB5AHoAewB8AH0AfgB/",
        "AIAAlQCWAJsApACuAK8AtwC/AMgA0ADUANYA2gDeAOIA5gDxAPUA/QD+AP8BCAEJAREBHAEgATABMQEyATMBNAE1AUcBTAFWAWIB",
        "bAFtAXcBeAF5AYIBiwGTAZcByQHKAcsBzAHNAc4BzwHQAdEB0gHTAdQB1QHWAdcB2AHZAdoB2wHcAd0B5gHuAfgB+QIBAgICCwIU",
        "Ah0CJgIuAjcCQAJIAlECXAJoAnICfAKFAo0ClgKfAqcCsAK6Ar4CwgLNAtEC3wLgAuEC4gLjAuwC9QL/AwgDEQMcAyADLAMtAy4D",
        "LwM5AzoDQwNMA1UDWQNnA2gDaQNqA3IDegODA4wDkAOUA58DowPDA8QDxQPGA8cDyAPJA8oDywPMA80DzgPPA9gD4QPqA/MD/AQF",
        "BA4EFwQgBCkEMgQ7BEQETQRYBFwEZgRnBGgEcQR6BIQEkASaBKYEqgS8BL0EvgS/BMAEwQTCBMoE0wTbAI4E5ATtBPUE/QUBBQUF",
        "CQUVBRYFFwUYBSEFKgUyBTYFOgVFBUkFUwVUBVUFXgVnBXAFewV/BYcFiAWRBZoFngWfBaJVJG51bGzWAA0ADgAPABAAEQASABMA",
        "FAAVABYAFwAYWk5TRW50aXRpZXNfEBZDRE1Db21waWxlclRvb2xWZXJzaW9uXxAXQ0RNQ29tcGlsZXJYY29kZVZlcnNpb25fEBdO",
        "U0ZldGNoUmVxdWVzdFRlbXBsYXRlc18QFE5TVmVyc2lvbklkZW50aWZpZXJzViRjbGFzc4ACI0DYqEAAAAAAEgAEHrCAAIDtgPDT",
        "ABoAGwASABwAKgA4V05TLmtleXNaTlMub2JqZWN0c60AHQAeAB8AIAAhACIAIwAkACUAJgAnACgAKYADgASABYAGgAeACIAJgAqA",
        "C4AMgA2ADoAPrQArACwALQAuAC8AMAAxADIAMwA0ADUANgA3gBCAK4AzgD6AeYCFgG2Am4C4gMKAwIDfgOeAEltDREFzc2V0SW5m",
        "b18QEUNETWV0YWRhdGFWZXJzaW9uXENEQ2hhaW5Bc3NldFdDRENoYWluXUNEQ29udGFjdEl0ZW1fEBVDRFJ1bnRpbWVNZXRhZGF0",
        "YUl0ZW1bQ0RDaGFpbk5vZGVfEBhDRFRyYW5zYWN0aW9uSGlzdG9yeUl0ZW1WQ0ROb2RlWkNEUG9vbEluZm9YQ0RDb25maWdeQ0RQ",
        "aGlzaGluZ0l0ZW1fEBJDRENoYWluU3RvcmFnZUl0ZW3bAEcAEgBIAEkASgBLAEwATQBOAE8AUAAdAFIAHQBUAFUAVgAWAFgAHQAJ",
        "ABZcTlNFbnRpdHlOYW1lXxAUTlNDbGFzc05hbWVGb3JFbnRpdHleTlNVbmlxdWVUdXBsZXNaTlNVc2VySW5mb11OU1N1YmVudGl0",
        "aWVzXxAVTlNWZXJzaW9uSGFzaE1vZGlmaWVyXE5TUHJvcGVydGllc18QFE5TUmVuYW1pbmdJZGVudGlmaWVyXxAUTlNNYW5hZ2Vk",
        "T2JqZWN0TW9kZWxdTlNTdXBlcmVudGl0eYADgCqAA4AngCWAEYAAgBOAA4ABgADTABoAGwASAF0AXgA4oKCAEtIAYQBiAGMAZFok",
        "Y2xhc3NuYW1lWCRjbGFzc2VzXxATTlNNdXRhYmxlRGljdGlvbmFyeaMAYwBlAGZcTlNEaWN0aW9uYXJ5WE5TT2JqZWN00wAaABsA",
        "EgBoAHAAOKcAaQBqAGsAbABtAG4Ab4AUgBWAFoAXgBiAGYAapwBxAHIAcwB0AHUAdgB3gBuAHoAfgCGAIoAjgCSAElZzeW1ib2xX",
        "YXNzZXRJZFd2aXNpYmxlWXByZWNpc2lvblppZGVudGlmaWVyVGljb25UbmFtZdsAEgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwCM",
        "AI0AjgArABYAaQAWAJMAaVJfUF8QGU5TQXR0cmlidXRlVmFsdWVDbGFzc05hbWVfEA9OU0F0dHJpYnV0ZVR5cGVcTlNJc09wdGlv",
        "bmFsWE5TRW50aXR5Xk5TRGVmYXVsdFZhbHVlXk5TUHJvcGVydHlOYW1lXxAWTlNWYWx1ZVRyYW5zZm9ybWVyTmFtZVpOU0ZsYWdz",
        "S2V5gB0Q84AcEQK8CYAQgACAFIAAEACAFFhOU1N0cmluZ9IAYQBiAJcAmF8QFk5TQXR0cmlidXRlRGVzY3JpcHRpb26jAJkAmgBm",
        "XxAWTlNBdHRyaWJ1dGVEZXNjcmlwdGlvbl8QFU5TUHJvcGVydHlEZXNjcmlwdGlvbtoAEgCGAIEAgwCCAIUAiACHAIkATgCKABYA",
        "ngCNAIwAKwAWAGoAkwBqgB2AABDxgByAEIAAgBWAFdsAEgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwCmAKcAjgArABYAawAWAJMA",
        "a4AdgCARAyAJgBCAAIAWgACAFlhOU051bWJlctoAEgCGAIEAgwCCAIUAiACHAIkATgCKABYAngCNAIwAKwAWAGwAkwBsgB2AAIAc",
        "gBCAAIAXgBfaABIAhgCBAIMAggCFAIgAhwCJAE4AigAWAJ4AjQCMACsAFgBtAJMAbYAdgACAHIAQgACAGIAY2wASAIEAggCDAIQA",
        "hQCGAIcAiACJAE4AigCLAIwAjQCOACsAFgBuABYAkwBugB2AHAmAEIAAgBmAAIAZ2gASAIYAgQCDAIIAhQCIAIcAiQBOAIoAFgCe",
        "AI0AjAArABYAbwCTAG+AHYAAgByAEIAAgBqAGtMAGgAbABIA0QDSANOgoIAm0gBhAGIAZQDVogBlAGbSABsAEgDXANmhANiAKIAp",
        "0gAbABIA2wDZoQBqgBWAKdIAYQBiAN8A4F5OU011dGFibGVBcnJheaMA3wDhAGZXTlNBcnJhedIAYQBiAOMA5F8QE05TRW50aXR5",
        "RGVzY3JpcHRpb26iAOUAZl8QE05TRW50aXR5RGVzY3JpcHRpb27aAEcAEgBIAEoASwBMAE0ATgBPAFAAHgBSAB4AVQDrABYA7QAe",
        "AAkAFoAEgCqABIAlgCyAAIAtgASAAYAA0wAaABsAEgDyAPMAOKCggBLTABoAGwASAPYA+QA4ogD3APiALoAvogD6APuAMIAygBJf",
        "EBJ0cmFuc2FjdGlvblZlcnNpb25bc3BlY1ZlcnNpb27aABIAhgCBAIMAggCFAIgAhwCJAE4AigEBAJ4BAgCmACwAFgD3AJMA94Ad",
        "gDEQyIAggCuAAIAugC4QANoAEgCGAIEAgwCCAIUAiACHAIkATgCKAQEAngECAKYALAAWAPgAkwD4gB2AMYAggCuAAIAvgC/aAEcA",
        "EgBIAEoASwBMAE0ATgBPAFAAHwBSAB8AVQEWABYBGAAfAAkAFoAFgCqABYAlgDSAAIA1gAWAAYAA0wAaABsAEgEdAR4AOKCggBLT",
        "ABoAGwASASEBKAA4pgEiASMBJAElASYAaoA2gDeAOIA5gDqAFaYBKQEqASsBLAEtAS6AO4A9gEGARIBFgEaAElVhc3NldFVjaGFp",
        "bl8QEXB1cmNoYXNlUHJvdmlkZXJzV3N0YWtpbmdUdHlwZd0AgQE2AIUBNwASATgBOQCEAToAhwBOATsBPACLACsALQE/AUAAFgAW",
        "AI4BPwEiASIAkwAdXxATTlNEZXN0aW5hdGlvbkVudGl0eVxOU0RlbGV0ZVJ1bGVfEBVOU0ludmVyc2VSZWxhdGlvbnNoaXBfEBpf",
        "TlNJbnZlcnNlUmVsYXRpb25zaGlwTmFtZVpOU01heENvdW50Wk5TTWluQ291bnRfEBhfTlNEZXN0aW5hdGlvbkVudGl0eU5hbWWA",
        "EIAzEAGAPIAAgAAJgDaANoAD0gBhAGIBSAFJXxAZTlNSZWxhdGlvbnNoaXBEZXNjcmlwdGlvbqMBSgFLAGZfEBlOU1JlbGF0aW9u",
        "c2hpcERlc2NyaXB0aW9uXxAVTlNQcm9wZXJ0eURlc2NyaXB0aW9u3QCBATYAhQE3ABIBOAE5AIQBOgCHAE4BOwE8AIsALgAtAT8B",
        "QAFQAVEAjgE/ASMBIwCTACCAPoAzgDyAP4BACYA3gDeABtsARwASAEgASQBKAEsATABNAE4ATwBQACAAUgAgAVoAVQFcABYBXgAg",
        "AAkAFoAGgCqABoB3gCWAR4AAgEiABoABgADdAIEBNgCFATcAEgE4ATkAhAE6AIcATgE7ATwAiwAtAC4BPwFAASoBIwCOAJMBUQFR",
        "AJMAH4AzgD6APIA9gDcJgECAQIAFVmFzc2V0c9sAEgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwFvAXAAjgAtABYBJAF1AJMBJIAd",
        "gEIRBwgJgDOAAIA4gEOAOFhbU3RyaW5nXV8QGU5TU2VjdXJlVW5hcmNoaXZlRnJvbURhdGHbABIAgQCCAIMAhACFAIYAhwCIAIkA",
        "TgCKAIsAjACNAI4ALQAWASUAFgCTASWAHYAcCYAzgACAOYAAgDnbABIAgQCCAIMAhACFAIYAhwCIAIkATgCKAIsAjACNAI4ALQAW",
        "ASYAFgCTASaAHYAcCYAzgACAOoAAgDraABIAhgCBAIMAggCFAIgAhwCJAE4AigAWAJ4AjQCMAC0AFgBqAJMAaoAdgACAHIAzgACA",
        "FYAV0wAaABsAEgGUAZUAOKCggBLTABoAGwASAZgBsAA4rxAXAZkBmgGbAZwAbgGeAZ8BUQGhAG8BowGkAaUBpgGnAagBqQGqAasB",
        "rAGtAa4Br4BJgEqAS4BMgBmATYBOgECAT4AagFCAUYBSgFOAVIBVgFaAV4BYgFmAWoBbgFyvEBcBsQGyAbMBtAG1AbYBtwFQAbkB",
        "ugG7AbwBvQG+Ab8BwAHBAcIBwwHEAcUBxgHHgF2AXoBfgGGAY4BkgGWAP4BmgGeAaIBpgGqAa4BsgG+AcIBxgHKAc4B0gHWAdoAS",
        "XWFkZHJlc3NQcmVmaXhXY2hhaW5JZF1zdGFraW5nQXBpVXJsXWhhc0Nyb3dkbG9hbnNeaGlzdG9yeUFwaVR5cGVdaXNUaXBSZXF1",
        "aXJlZF8QEW1pbmltYWxBcHBWZXJzaW9uXxATdHlwZXNPdmVycmlkZUNvbW1vblV0eXBlc1lpc1Rlc3RuZXRec3Rha2luZ0FwaVR5",
        "cGVVbm9kZXNcc2VsZWN0ZWROb2RlWHBhcmVudElkVmlzT3JtbF8QEWNyb3dkbG9hbnNBcGlUeXBlXxAQY3Jvd2Rsb2Fuc0FwaVVy",
        "bF8QD2lzRXRoZXJldW1CYXNlZF1oaXN0b3J5QXBpVXJsW2N1c3RvbU5vZGVz2gASAIYAgQCDAIIAhQCIAIcAiQBOAIoBAQCeAeAA",
        "pgAuABYBmQCTAZmAHYAxEGSAIIA+gACASYBJ2gASAIYAgQCDAIIAhQCIAIcAiQBOAIoAFgCeAI0AjAAuABYBmgCTAZqAHYAAgByA",
        "PoAAgEqAStsAEgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwHwAfEAjgAuABYBmwAWAJMBm4AdgGARBLAJgD6AAIBLgACAS1VOU1VS",
        "TNoAEgCGAIEAgwCCAIUAiACHAIkATgCKAfsAngCnAKYALgAWAZwAkwGcgB2AYoAggD6AAIBMgEwI2wASAIEAggCDAIQAhQCGAIcA",
        "iACJAE4AigCLAfAB8QCOAC4AFgBuABYAkwBugB2AYAmAPoAAgBmAAIAZ2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAIwAjQCO",
        "AC4AFgGeABYAkwGegB2AHAmAPoAAgE2AAIBN2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAKYApwCOAC4AFgGfABYAkwGfgB2A",
        "IAmAPoAAgE6AAIBO2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAIwAjQCOAC4AFgGhABYAkwGhgB2AHAmAPoAAgE+AAIBP2gAS",
        "AIYAgQCDAIIAhQCIAIcAiQBOAIoAFgCeAI0AjAAuABYAbwCTAG+AHYAAgByAPoAAgBqAGtsAEgCBAIIAgwCEAIUAhgCHAIgAiQBO",
        "AIoAiwCmAKcAjgAuABYBowAWAJMBo4AdgCAJgD6AAIBQgACAUNsAEgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwHwAfEAjgAuABYB",
        "pAAWAJMBpIAdgGAJgD6AAIBRgACAUdoAEgCGAIEAgwCCAIUAiACHAIkATgCKAfsAngCnAKYALgAWAaUAkwGlgB2AYoAggD6AAIBS",
        "gFLbABIAgQCCAIMAhACFAIYAhwCIAIkATgCKAIsAjACNAI4ALgAWAaYAFgCTAaaAHYAcCYA+gACAU4AAgFPdAIEBNgCFATcAEgE4",
        "ATkAhAE6AIcATgE7ATwAiwAxAC4CVAFAAlYBIwCOAJMBpwGnAT8AI4BtgD4QAoA8gG6ANwmAVIBUgAnbAEcAEgBIAEkASgBLAEwA",
        "TQBOAE8AUAAjAFIAIwJgAFUCYgAWAmQAIwAJABaACYAqgAmAmYAlgJCAAICRgAmAAYAA3QCBATYAhQE3ABIBOAE5AIQBOgCHAE4B",
        "OwE8AIsALgAxAJMBQAG/AacAjgE/ASMBIwCTACCAPoBtgDyAbIBUCYA3gDeABt0AgQE2AIUBNwASATgBOQCEAToAhwBOATsBPACL",
        "ADEALgE/AUAAFgAWAI4BPwGoAagAkwAjgG2APoA8gACAAAmAVYBVgAnbABIAgQCCAIMAhACFAIYAhwCIAIkATgCKAIsAjACNAI4A",
        "LgAWAakAFgCTAamAHYAcCYA+gACAVoAAgFbaABIAhgCBAIMAggCFAIgAhwCJAE4AigH7AJ4ApwCmAC4AFgGqAJMBqoAdgGKAIIA+",
        "gACAV4BX2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAIwAjQCOAC4AFgGrABYAkwGrgB2AHAmAPoAAgFiAAIBY2wASAIEAggCD",
        "AIQAhQCGAIcAiACJAE4AigCLAfAB8QCOAC4AFgGsABYAkwGsgB2AYAmAPoAAgFmAAIBZ2gASAIYAgQCDAIIAhQCIAIcAiQBOAIoB",
        "+wCeAKcApgAuABYBrQCTAa2AHYBigCCAPoAAgFqAWtsAEgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwHwAfEAjgAuABYBrgAWAJMB",
        "roAdgGAJgD6AAIBbgACAW90AgQE2AIUBNwASATgBOQCEAToAhwBOATsBPACLADEALgJUAUAAFgAWAI4AkwGvAa8AkwAjgG2APoA8",
        "gACAAAmAXIBcgAnSABsAEgK7ANmhAryAeIAp0gAbABICvwDZoQGagEqAKdoARwASAEgASgBLAEwATQBOAE8AUAAhAFIAIQBVAscA",
        "FgLJACEACQAWgAeAKoAHgCWAeoAAgHuAB4ABgADTABoAGwASAs4CzwA4oKCAEtMAGgAbABIC0gLYADilAtMC1ALVAG0C14B8gH2A",
        "foAYgH+lAtkC2gLbAtwC3YCAgIGAgoCDgISAEltwZWVyQWRkcmVzc110YXJnZXRBZGRyZXNzWXVwZGF0ZWRBdFhwZWVyTmFtZdsA",
        "EgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwCMAI0AjgAvABYC0wAWAJMC04AdgBwJgHmAAIB8gACAfNsAEgCBAIIAgwCEAIUAhgCH",
        "AIgAiQBOAIoAiwCMAI0AjgAvABYC1AAWAJMC1IAdgBwJgHmAAIB9gACAfdsAEgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwCmAvgA",
        "jgAvAQEC1QAWAJMC1YAdgCARASwJgHmAMYB+gACAftsAEgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwCMAI0AjgAvABYAbQAWAJMA",
        "bYAdgBwJgHmAAIAYgACAGNsAEgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwCMAI0AjgAvABYC1wAWAJMC14AdgBwJgHmAAIB/gACA",
        "f9oARwASAEgASgBLAEwATQBOAE8AUAAiAFIAIgBVAxYAFgMYACIACQAWgAiAKoAIgCWAhoAAgIeACIABgADTABoAGwASAx0DHgA4",
        "oKCAEtMAGgAbABIDIQMmADikAyIDIwBtAyWAiICJgBiAiqQDJwMoAykDKoCLgI2AjoCPgBJYbWV0YWRhdGFZdHhWZXJzaW9uV3Zl",
        "cnNpb27bABIAgQCCAIMAhACFAIYAhwCIAIkATgCKAIsDMQMyAI4AMAAWAyIAFgCTAyKAHYCMEQPoCYCFgACAiIAAgIhWTlNEYXRh",
        "2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAKYBAgCOADABAQMjABYAkwMjgB2AIAmAhYAxgImAAICJ2wASAIEAggCDAIQAhQCG",
        "AIcAiACJAE4AigCLAIwAjQCOADAAFgBtABYAkwBtgB2AHAmAhYAAgBiAAIAY2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAKYB",
        "AgCOADABAQMlABYAkwMlgB2AIAmAhYAxgIqAAICK0wAaABsAEgNWA1cAOKCggBLTABoAGwASA1oDYAA4pQNbASMAbwNeA1+AkoA3",
        "gBqAk4CUpQNhAlYDYwNkA2WAlYBugJaAl4CYgBJTdXJsWmFwaUtleU5hbWVcYXBpUXVlcnlOYW1l2gASAIYAgQCDAIIAhQCIAIcA",
        "iQBOAIoAFgCeAfEB8AAxABYDWwCTA1uAHYAAgGCAbYAAgJKAktoAEgCGAIEAgwCCAIUAiACHAIkATgCKABYAngCNAIwAMQAWAG8A",
        "kwBvgB2AAIAcgG2AAIAagBrbABIAgQCCAIMAhACFAIYAhwCIAIkATgCKAIsAjACNAI4AMQAWA14AFgCTA16AHYAcCYBtgACAk4AA",
        "gJPbABIAgQCCAIMAhACFAIYAhwCIAIkATgCKAIsAjACNAI4AMQAWA18AFgCTA1+AHYAcCYBtgACAlIAAgJTSABsAEgONANmhA46A",
        "moAp0gAbABIDkQDZoQNbgJKAKdoARwASAEgASgBLAEwATQBOAE8AUAAkAFIAJABVA5kAFgObACQACQAWgAqAKoAKgCWAnIAAgJ2A",
        "CoABgADTABoAGwASA6ADoQA4oKCAEtMAGgAbABIDpAOzADiuA6UDpgOnA6gDqQOqA6sAbQOtAGoDrwOwA7EDsoCegJ+AoIChgKKA",
        "o4CkgBiApYAVgKaAp4CogKmuA7QDtQO2A7cDuAO5A7oDuwO8A70DvgO/A8ADwYCqgKuArICtgK6Ar4CwgLGAsoCzgLSAtYC2gLeA",
        "ElhjYWxsTmFtZVd0eEluZGV4WHJlY2VpdmVyVmFtb3VudFl0aW1lc3RhbXBTZmVlWm1vZHVsZU5hbWVVbHBGZWVUY2FsbFtibG9j",
        "a051bWJlclZzZW5kZXJWc3RhdHVz2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAIwAjQCOADIAFgOlABYAkwOlgB2AHAmAm4AA",
        "gJ6AAICe2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAKYB4ACOADIAFgOmABYAkwOmgB2AIAmAm4AAgJ+AAICf2wASAIEAggCD",
        "AIQAhQCGAIcAiACJAE4AigCLAIwAjQCOADIAFgOnABYAkwOngB2AHAmAm4AAgKCAAICg2wASAIEAggCDAIQAhQCGAIcAiACJAE4A",
        "igCLAIwAjQCOADIAFgOoABYAkwOogB2AHAmAm4AAgKGAAICh2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAKYC+ACOADIBAQOp",
        "ABYAkwOpgB2AIAmAm4AxgKKAAICi2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAIwAjQCOADIAFgOqABYAkwOqgB2AHAmAm4AA",
        "gKOAAICj2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAIwAjQCOADIAFgOrABYAkwOrgB2AHAmAm4AAgKSAAICk2wASAIEAggCD",
        "AIQAhQCGAIcAiACJAE4AigCLAIwAjQCOADIAFgBtABYAkwBtgB2AHAmAm4AAgBiAAIAY2wASAIEAggCDAIQAhQCGAIcAiACJAE4A",
        "igCLAIwAjQCOADIAFgOtABYAkwOtgB2AHAmAm4AAgKWAAICl2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAIwAjQCOADIAFgBq",
        "ABYAkwBqgB2AHAmAm4AAgBWAAIAV2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAzEDMgCOADIAFgOvABYAkwOvgB2AjAmAm4AA",
        "gKaAAICm2wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAKYC+ACOADIAFgOwABYAkwOwgB2AIAmAm4AAgKeAAICn2wASAIEAggCD",
        "AIQAhQCGAIcAiACJAE4AigCLAIwAjQCOADIAFgOxABYAkwOxgB2AHAmAm4AAgKiAAICo2wASAIEAggCDAIQAhQCGAIcAiACJAE4A",
        "igCLAKYB4ACOADIBAQOyABYAkwOygB2AIAmAm4AxgKmAAICp2gBHABIASABKAEsATABNAE4ATwBQACUAUgAlAFUEUgAWBFQAJQAJ",
        "ABaAC4AqgAuAJYC5gACAuoALgAGAANMAGgAbABIEWQRaADigoIAS0wAaABsAEgRdBGEAOKMEXgBvBGCAu4AagLyjBGIEYwRkgL2A",
        "voC/gBJXYWRkcmVzc1Zjb25maWfbABIAgQCCAIMAhACFAIYAhwCIAIkATgCKAIsAjACNAI4AMwAWBF4AFgCTBF6AHYAcCYC4gACA",
        "u4AAgLvbABIAgQCCAIMAhACFAIYAhwCIAIkATgCKAIsAjACNAI4AMwAWAG8AFgCTAG+AHYAcCYC4gACAGoAAgBrdAIEBNgCFATcA",
        "EgE4ATkAhAE6AIcATgE7ATwAiwA1ADMBPwFABH4BpwCOAT8EYARgAJMAJ4DAgLiAPIDBgFQJgLyAvIAN2wBHABIASABJAEoASwBM",
        "AE0ATgBPAFAAJwBSACcEiABVBIoAFgSMACcACQAWgA2AKoANgN2AJYDVgACA1oANgAGAAN0AgQE2AIUBNwASATgBOQCEAToAhwBO",
        "ATsBPACLADMANQE/AUAEZARgAI4AkwGnAacAkwAlgLiAwIA8gL+AvAmAVIBUgAvbAEcAEgBIAEkASgBLAEwATQBOAE8AUAAmAFIA",
        "JgSeAFUEoAAWBKIAJgAJABaADIAqgAyA04AlgMOAAIDEgAyAAYAA0wAaABsAEgSnBKgAOKCggBLTABoAGwASBKsEswA4pwSsBK0E",
        "rgSvAG0EsQSygMWAxoDHgMiAGIDJgMqnBLQEtQS2BLcEuAS5BLqAy4DMgM2AzoDQgNGA0oASVnBvb2xJZFlhY2NvdW50SWRVb3Jk",
        "ZXJaaXNGYXZvcml0ZV10YXJnZXRBc3NldElkW2Jhc2VBc3NldElk2gASAIYAgQCDAIIAhQCIAIcAiQBOAIoAFgCeAI0AjAA0ABYE",
        "rACTBKyAHYAAgByAwoAAgMWAxdsAEgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwCMAI0AjgA0ABYErQAWAJMErYAdgBwJgMKAAIDG",
        "gACAxtoAEgCGAIEAgwCCAIUAiACHAIkATgCKAQEAngL4AKYANAAWBK4AkwSugB2AMYAggMKAAIDHgMfaABIAhgCBAIMAggCFAIgA",
        "hwCJAE4AigTdAJ4ApwCmADQAFgSvAJMEr4AdgM+AIIDCgACAyIDICdsAEgCBAIIAgwCEAIUAhgCHAIgAiQBOAIoAiwCMAI0AjgA0",
        "ABYAbQAWAJMAbYAdgBwJgMKAAIAYgACAGNoAEgCGAIEAgwCCAIUAiACHAIkATgCKABYAngCNAIwANAAWBLEAkwSxgB2AAIAcgMKA",
        "AIDJgMnaABIAhgCBAIMAggCFAIgAhwCJAE4AigAWAJ4AjQCMADQAFgSyAJMEsoAdgACAHIDCgACAyoDK0gAbABIE/gDZoQT/gNSA",
        "KdIAGwASBQIA2aEErIDFgCnTABoAGwASBQYFBwA4oKCAEtMAGgAbABIFCgUPADikBQsFDAUNAaeA14DYgNmAVKQFEAURBRIEfoDa",
        "gNuA3IDBgBJbZXhwbG9yZXJVcmxYdHlwZXNVcmxYY29uZmlnSWTbABIAgQCCAIMAhACFAIYAhwCIAIkATgCKAIsAjACNAI4ANQAW",
        "BQsAFgCTBQuAHYAcCYDAgACA14AAgNfbABIAgQCCAIMAhACFAIYAhwCIAIkATgCKAIsAjACNAI4ANQAWBQwAFgCTBQyAHYAcCYDA",
        "gACA2IAAgNjaABIAhgCBAIMAggCFAIgAhwCJAE4AigAWAJ4AjQCMADUAFgUNAJMFDYAdgACAHIDAgACA2YDZ0gAbABIFMwDZoQU0",
        "gN6AKdIAGwASBTcA2aEFDYDZgCnaAEcAEgBIAEoASwBMAE0ATgBPAFAAKABSACgAVQU/ABYFQQAoAAkAFoAOgCqADoAlgOCAAIDh",
        "gA6AAYAA0wAaABsAEgVGBUcAOKCggBLTABoAGwASBUoFTgA4owVLBUwAbYDigOOAGKMFTwVQBVGA5IDlgOaAElZzb3VyY2VZcHVi",
        "bGljS2V52wASAIEAggCDAIQAhQCGAIcAiACJAE4AigCLAIwAjQCOADYAFgVLABYAkwVLgB2AHAmA34AAgOKAAIDi2wASAIEAggCD",
        "AIQAhQCGAIcAiACJAE4AigCLAIwAjQCOADYAFgVMABYAkwVMgB2AHAmA34AAgOOAAIDj2wASAIEAggCDAIQAhQCGAIcAiACJAE4A",
        "igCLAIwAjQCOADYAFgBtABYAkwBtgB2AHAmA34AAgBiAAIAY2gBHABIASABKAEsATABNAE4ATwBQACkAUgApAFUFdQAWBXcAKQAJ",
        "ABaAD4AqgA+AJYDogACA6YAPgAGAANMAGgAbABIFfAV9ADigoIAS0wAaABsAEgWABYMAOKIFgQBtgOqAGKIFhAWFgOuA7IASVGRh",
        "dGHbABIAgQCCAIMAhACFAIYAhwCIAIkATgCKAIsDMQMyAI4ANwAWBYEAFgCTBYGAHYCMCYDngACA6oAAgOrbABIAgQCCAIMAhACF",
        "AIYAhwCIAIkATgCKAIsAjACNAI4ANwAWAG0AFgCTAG2AHYAcCYDngACAGIAAgBjSABsAEgWbBZ2hBZyA7oDvUNIAYQBiBaAFoVVO",
        "U1NldKIFoABm0gBhAGIFowWkXxAUTlNNYW5hZ2VkT2JqZWN0TW9kZWyiBaUAZl8QFE5TTWFuYWdlZE9iamVjdE1vZGVsAAgAGQAi",
        "ACwAMQA6AD8AUQBWAFsAXQJCAkgCYQJsAoUCnwK5AtAC1wLZAuIC5wLpAusC7QL6AwIDDQMoAyoDLAMuAzADMgM0AzYDOAM6AzwD",
        "PgNAA0IDXQNfA2EDYwNlA2cDaQNrA20DbwNxA3MDdQN3A3kDhQOZA6YDrgO8A9QD4AP7BAIEDQQWBCUEOgRnBHQEiwSaBKUEswTL",
        "BNgE7wUGBRQFFgUYBRoFHAUeBSAFIgUkBSYFKAUqBTcFOAU5BTsFRAVPBVgFbgV1BYIFiwWYBacFqQWrBa0FrwWxBbMFtQXEBcYF",
        "yAXKBcwFzgXQBdIF1AXbBeMF6wX1BgAGBQYKBjcGOgZWBmgGdQZ+Bo0GnAa1BsAGwgbEBsYGyQbKBswGzgbQBtIG1AbWBt8G6AcB",
        "BwgHIQc5B2IHZAdmB2gHagdsB24HcAdyB58HoQejB6YHpwepB6sHrQevB7EHugfjB+UH5wfpB+sH7QfvB/EIGggcCB4IIAgiCCQI",
        "JggoCFUIVwhZCFoIXAheCGAIYghkCI0IjwiRCJMIlQiXCJkImwioCKkIqgisCLUIugjDCMYIyAjKCNMI1gjYCNoI4wjyCPkJAQkK",
        "CSAJJQk7CWQJZgloCWoJbAluCXAJcgl0CXYJeAmFCYYJhwmJCZYJmwmdCZ8JpAmmCagJqgm/CcsJ9An2CfgJ+gn8Cf4KAAoCCgQK",
        "BgovCjEKMwo1CjcKOQo7Cj0KZgpoCmoKbApuCnAKcgp0CnYKeAp6CocKiAqJCosKmAqlCqcKqQqrCq0KrwqxCr4KwArCCsQKxgrI",
        "CsoKzArSCtgK7Ar0CvkLLgtEC1ELaQuGC5ELnAu3C7kLuwu9C78LwQvDC8QLxgvIC8oL0wvvC/YMEgwqDF8MYQxjDGUMZwxpDGoM",
        "bAxuDHAMnQyfDKEMowylDKcMqQyrDK0MrwyxDLMM6AzqDOwM7gzwDPIM8wz1DPcM+Q0ADS0NLw0xDTQNNQ03DTkNOw09DT8NSA1k",
        "DZENkw2VDZYNmA2aDZwNng2gDc0Nzw3RDdIN1A3WDdgN2g3cDgUOBw4JDgsODQ4PDhEOEw4gDiEOIg4kDjEOYg5kDmYOaA5qDmwO",
        "bg5wDnIOdA52DngOeg58Dn4OgA6CDoQOhg6IDooOjA6ODpAOwQ7DDsUOxw7JDssOzQ7PDtEO0w7VDtcO2Q7bDt0O3w7hDuMO5Q7n",
        "DukO6w7tDu8O8Q7/DwcPFQ8jDzIPQA9UD2oPcA96D4kPjw+cD6UPrA/AD9MP5Q/zD/8QKBAqECwQLhAwEDIQNBA2EDgQYRBjEGUQ",
        "ZxBpEGsQbRBvEJwQnhCgEKMQpBCmEKgQqhCsEK4QtBDdEN8Q4RDjEOUQ5xDpEOsQ7BEZERsRHREeESARIhEkESYRKBFVEVcRWRFa",
        "EVwRXhFgEWIRZBGREZMRlRGWEZgRmhGcEZ4RoBHNEc8R0RHSEdQR1hHYEdoR3BIFEgcSCRILEg0SDxIREhMSQBJCEkQSRRJHEkkS",
        "SxJNEk8SfBJ+EoASgRKDEoUShxKJEosStBK2ErgSuhK8Er4SwBLCEu8S8RLzEvQS9hL4EvoS/BL+EzMTNRM3EzkTOxM9Ez8TQBNC",
        "E0QTRhNzE3UTdxN5E3sTfRN/E4ETgxOFE4cTiRO+E8ATwhPEE8YTyBPJE8sTzRPPFAQUBhQIFAoUDBQOFA8UERQTFBUUQhREFEYU",
        "RxRJFEsUTRRPFFEUehR8FH4UgBSCFIQUhhSIFLUUtxS5FLoUvBS+FMAUwhTEFPEU8xT1FPYU+BT6FPwU/hUAFSkVKxUtFS8VMRUz",
        "FTUVNxVkFWYVaBVpFWsVbRVvFXEVcxWoFaoVrBWuFbAVshWzFbUVtxW5FcIVxRXHFckV0hXVFdcV2RYCFgQWBhYIFgoWDBYOFhAW",
        "EhYUFhYWIxYkFiUWJxY0Fj8WQRZDFkUWRxZJFlQWVhZYFloWXBZeFmAWbBZ6FoQWjRa6FrwWvha/FsEWwxbFFscWyRb2FvgW+hb7",
        "Fv0W/xcBFwMXBRcyFzQXNhc5FzoXPBc+F0AXQhdEF3EXcxd1F3YXeBd6F3wXfheAF60XrxexF7IXtBe2F7gXuhe8F+UX5xfpF+sX",
        "7RfvF/EX8xf1F/cX+RgGGAcYCBgKGBcYIBgiGCQYJhgoGDEYMxg1GDcYORg7GEQYThhWGIMYhRiHGIoYixiNGI8YkRiTGJUYnBjJ",
        "GMsYzRjOGNAY0hjUGNYY2BkFGQcZCRkKGQwZDhkQGRIZFBlBGUMZRRlGGUgZShlMGU4ZUBldGV4ZXxlhGW4ZeRl7GX0ZfxmBGYMZ",
        "jhmQGZIZlBmWGZgZmhmeGakZthnfGeEZ4xnlGecZ6RnrGe0aFhoYGhoaHBoeGiAaIhokGlEaUxpVGlYaWBpaGlwaXhpgGo0ajxqR",
        "GpIalBqWGpgamhqcGqUaqBqqGqwatRq4GroavBrlGuca6RrrGu0a7xrxGvMa9Rr3GvkbBhsHGwgbChsXGzQbNhs4GzobPBs+G0Ab",
        "QhtEG0YbSBtKG0wbThtQG20bbxtxG3MbdRt3G3kbext9G38bgRuDG4UbhxuJG4sblBucG6UbrBu2G7obxRvLG9Ab3BvjG+ocFxwZ",
        "HBscHBweHCAcIhwkHCYcUxxVHFccWBxaHFwcXhxgHGIcjxyRHJMclByWHJgcmhycHJ4cyxzNHM8c0BzSHNQc1hzYHNodBx0JHQsd",
        "DB0OHRAdEh0UHRYdQx1FHUcdSB1KHUwdTh1QHVIdfx2BHYMdhB2GHYgdih2MHY4dux29Hb8dwB3CHcQdxh3IHcod9x35Hfsd/B3+",
        "HgAeAh4EHgYeMx41HjceOB46HjwePh5AHkIebx5xHnMedB52Hngeeh58Hn4eqx6tHq8esB6yHrQeth64Hroe5x7pHuse7B7uHvAe",
        "8h70HvYfIx8lHycfKB8qHywfLh8wHzIfWx9dH18fYR9jH2UfZx9pH2sfbR9vH3wffR9+H4AfjR+UH5YfmB+aH6Efox+lH6cfqR+x",
        "H7gf5R/nH+kf6h/sH+4f8B/yH/QgISAjICUgJiAoICogLCAuIDAgZSBnIGkgayBtIG8gcCByIHQgdiCjIKUgpyCpIKsgrSCvILEg",
        "syC1ILcguSDuIPAg8iD0IPYg+CD5IPsg/SD/ISwhLiEwITIhNCE2ITghOiE8IT4hQCFCIU8hUCFRIVMhYCFvIXEhcyF1IXcheSF7",
        "IX0hjCGOIZAhkiGUIZYhmCGaIZwhoyGtIbMhviHMIdgiASIDIgUiByIJIgsiDSIPIjwiPiJAIkEiQyJFIkciSSJLInQidiJ4Inoi",
        "fCJ+IoAigiKrIq0iryKxIrMitSK3IrkiuiLnIuki6yLsIu4i8CLyIvQi9iMfIyEjIyMlIycjKSMrIy0jViNYI1ojXCNeI2AjYiNk",
        "I20jcCNyI3QjfSOAI4IjhCORI5IjkyOVI6IjqyOtI68jsSOzI7wjviPAI8IjxCPGI9Ij2yPkJBEkEyQVJBYkGCQaJBwkHiQgJE0k",
        "TyRRJFIkVCRWJFgkWiRcJIUkhySJJIskjSSPJJEkkyScJJ8koSSjJKwkrySxJLMk3CTeJOAk4iTkJOYk6CTqJOwk7iTwJP0k/iT/",
        "JQElDiUVJRclGSUbJSIlJCUmJSglKiUxJTslaCVqJWwlbSVvJXElcyV1JXclpCWmJaglqSWrJa0lryWxJbMl4CXiJeQl5SXnJekl",
        "6yXtJe8mGCYaJhwmHiYgJiImJCYmJigmKiYsJjkmOiY7Jj0mSiZPJlEmUyZYJlomXCZeJmMmkCaSJpQmlSaXJpkmmyadJp8mzCbO",
        "JtAm0SbTJtUm1ybZJtsm5CbnJukm6ybsJvUm+ycAJwknICclAAAAAAAAAgIAAAAAAAAFpgAAAAAAAAAAAAAAAAAAJzw="
    ]
}
