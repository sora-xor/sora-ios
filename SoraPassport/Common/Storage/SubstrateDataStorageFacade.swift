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

import RobinHood
import CoreData

/// What happened to an existing `SubstrateDataModel` store before it was opened.
enum SubstrateStorePreparation: Equatable {
    /// There is no store yet, or the store already matches the current model.
    case ready
    /// The store was written by an earlier model version and was migrated in place.
    case migrated
    /// The store matched no model version this build knows, or was not a database.
    /// It was removed, which is what earlier releases did with every model change.
    case removedIncompatible
    /// The store could not be read or migrated for a reason that can pass: the
    /// device has not been unlocked since it started, the disk is full, or an I/O
    /// error. The store is left untouched and this session uses a temporary
    /// in-memory store; the next launch tries again.
    case deferred
}

/// Opens the chain, node, contact and pool store across releases.
///
/// `SubstrateDataModel.xcdatamodeld` keeps every shipped schema:
/// - `SubstrateDataModel` (v1, 10 entities): 2.x to 3.8.5 and the 3.9.0 TestFlight builds;
/// - `SubstrateDataModel 2` (v2, current): an exact copy of App Store 3.8.6, which added
///   `CDConfig`, `CDMetadataVersion` and `CDNode`.
///
/// Before 3.9.0 the store was opened with RobinHood's `.removeStore`, which deleted it
/// whenever its schema differed from the app's (and whenever its metadata could not be
/// read, for example before the first unlock). An upgrade from 3.8.6 therefore lost the
/// user's contacts, custom and selected nodes and pool favourites. Now a store from any
/// known version is migrated in place (lightweight migration), and a store is removed only
/// when it is provably not usable. The store holds no key material.
enum SubstrateStoreMigrator {
    static let migrationOptions: [AnyHashable: Any] = [
        NSMigratePersistentStoresAutomaticallyOption: true,
        NSInferMappingModelAutomaticallyOption: true
    ]

    static func prepare(
        storeURL: URL,
        modelURL: URL,
        fileManager: FileManager = .default,
        logger: LoggerProtocol? = Logger.shared
    ) -> SubstrateStorePreparation {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return .ready
        }

        guard let currentModel = NSManagedObjectModel(contentsOf: modelURL) else {
            logger?.error("Substrate store: the bundled model could not be loaded")
            return .deferred
        }

        let metadata: [String: Any]
        do {
            metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
        } catch {
            switch databaseHeaderState(at: storeURL) {
            case .unreadable:
                logger?.warning("Substrate store: not readable now; using a temporary store")
                return .deferred
            case .notDatabase:
                return removeStore(at: storeURL, fileManager: fileManager, logger: logger)
            case .database:
                if isTransient(error) {
                    logger?.warning("Substrate store: metadata not readable now; using a temporary store")
                    return .deferred
                }
                return removeStore(at: storeURL, fileManager: fileManager, logger: logger)
            }
        }

        if currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
            return .ready
        }

        let isKnownVersion = knownModels(in: modelURL).contains {
            $0.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        guard isKnownVersion else {
            return removeStore(at: storeURL, fileManager: fileManager, logger: logger)
        }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)
        do {
            let store = try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: migrationOptions
            )
            try? coordinator.remove(store)
            logger?.info("Substrate store: migrated to the current model")
            return .migrated
        } catch {
            if isTransient(error) {
                logger?.warning("Substrate store: migration did not finish; using a temporary store")
                return .deferred
            }
            return removeStore(at: storeURL, fileManager: fileManager, logger: logger)
        }
    }

    /// Every compiled version inside the `.momd` bundle.
    static func knownModels(in modelURL: URL) -> [NSManagedObjectModel] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: modelURL,
            includingPropertiesForKeys: nil
        )) ?? []
        return urls
            .filter { $0.pathExtension == "mom" }
            .compactMap { NSManagedObjectModel(contentsOf: $0) }
    }

    enum DatabaseHeaderState {
        case database
        case notDatabase
        case unreadable
    }

    static func databaseHeaderState(at url: URL) -> DatabaseHeaderState {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return .unreadable
        }
        defer { try? handle.close() }
        let header: Data
        do {
            header = try handle.read(upToCount: 16) ?? Data()
        } catch {
            return .unreadable
        }
        return header == Data("SQLite format 3\u{0}".utf8) ? .database : .notDatabase
    }

    /// Errors that say "not now" rather than "never": locked or protected files, a full
    /// disk, I/O and busy databases. Core Data reports SQLite result codes in
    /// `NSSQLiteErrorDomain`; extended codes keep the primary code in the low byte.
    static func isTransient(_ error: Error) -> Bool {
        var pending: [NSError] = [error as NSError]
        var visited = 0
        while let next = pending.popLast(), visited < 16 {
            visited += 1
            if transientCodes[next.domain]?.contains(next.code) == true {
                return true
            }
            if let sqliteCode = next.userInfo["NSSQLiteErrorDomain"] as? Int,
               transientSQLiteCodes.contains(sqliteCode & 0xFF) {
                return true
            }
            if next.domain == "NSSQLiteErrorDomain", transientSQLiteCodes.contains(next.code & 0xFF) {
                return true
            }
            if let underlying = next.userInfo[NSUnderlyingErrorKey] as? NSError {
                pending.append(underlying)
            }
            if let detailed = next.userInfo[NSDetailedErrorsKey] as? [NSError] {
                pending.append(contentsOf: detailed)
            }
        }
        return false
    }

    private static let transientCodes: [String: Set<Int>] = [
        NSPOSIXErrorDomain: [
            Int(EPERM), Int(EIO), Int(EAGAIN), Int(EACCES), Int(EBUSY), Int(ENOSPC), Int(EDQUOT)
        ],
        NSCocoaErrorDomain: [
            NSFileLockingError,
            NSFileReadUnknownError,
            NSFileReadNoPermissionError,
            NSFileWriteUnknownError,
            NSFileWriteNoPermissionError,
            NSFileWriteOutOfSpaceError
        ]
    ]

    /// SQLITE_PERM, SQLITE_BUSY, SQLITE_LOCKED, SQLITE_IOERR, SQLITE_FULL,
    /// SQLITE_CANTOPEN, SQLITE_AUTH.
    private static let transientSQLiteCodes: Set<Int> = [3, 5, 6, 10, 13, 14, 23]

    private static func removeStore(
        at storeURL: URL,
        fileManager: FileManager,
        logger: LoggerProtocol?
    ) -> SubstrateStorePreparation {
        let path = storeURL.path
        for suffix in ["", "-wal", "-shm"] where fileManager.fileExists(atPath: path + suffix) {
            do {
                try fileManager.removeItem(atPath: path + suffix)
            } catch {
                logger?.warning("Substrate store: an unusable store could not be removed now")
                return .deferred
            }
        }
        logger?.warning("Substrate store: removed a store that no known model can open")
        return .removedIncompatible
    }
}

class SubstrateDataStorageFacade: StorageFacadeProtocol {
    static let shared = SubstrateDataStorageFacade()

    let databaseService: CoreDataServiceProtocol
    let preparation: SubstrateStorePreparation

    private init() {
        let modelName = "SubstrateDataModel"
        let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd")

        let baseURL = FileManager.default.urls(for: .documentDirectory,
                                               in: .userDomainMask).first?.appendingPathComponent("CoreData")

        let setup = Self.makeConfiguration(
            modelURL: modelURL!,
            databaseDirectory: baseURL!,
            databaseName: "\(modelName).sqlite"
        )
        preparation = setup.preparation
        databaseService = CoreDataService(configuration: setup.configuration)
    }

    /// The production configuration, shared with the tests: prepare the existing store
    /// first, then open it with migration options and without RobinHood's `.removeStore`.
    static func makeConfiguration(
        modelURL: URL,
        databaseDirectory: URL,
        databaseName: String,
        fileManager: FileManager = .default
    ) -> (configuration: CoreDataServiceConfiguration, preparation: SubstrateStorePreparation) {
        let storeURL = databaseDirectory.appendingPathComponent(databaseName)
        let preparation = SubstrateStoreMigrator.prepare(
            storeURL: storeURL,
            modelURL: modelURL,
            fileManager: fileManager
        )

        guard preparation != .deferred else {
            return (CoreDataServiceConfiguration(modelURL: modelURL, storageType: .inMemory), preparation)
        }

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: databaseDirectory,
            databaseName: databaseName,
            incompatibleModelStrategy: .ignore,
            options: SubstrateStoreMigrator.migrationOptions
        )

        return (
            CoreDataServiceConfiguration(modelURL: modelURL, storageType: .persistent(settings: persistentSettings)),
            preparation
        )
    }

    func createRepository<T, U>(filter: NSPredicate?,
                                sortDescriptors: [NSSortDescriptor],
                                mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
    where T: Identifiable, U: NSManagedObject {
            return CoreDataRepository(databaseService: databaseService,
                                      mapper: mapper, filter: filter,
                                      sortDescriptors: sortDescriptors)
    }
}
