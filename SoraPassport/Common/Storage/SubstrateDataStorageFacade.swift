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
    /// The store is unrecognized/corrupt, could not be migrated, or could not
    /// be opened on `maximumDeferredLaunches` readable, non-full launches. It was renamed aside (never deleted) and a new,
    /// empty store is used from now on.
    case movedAside
    /// The store could not be read or migrated for a reason that can pass: the
    /// device has not been unlocked since it started, the disk is full, or an I/O
    /// error. The store is left untouched and this session uses a temporary
    /// in-memory store; the next launch tries again.
    case deferred
}

/// Opens the chain, node, contact and pool store across releases.
///
/// `SubstrateDataModel.xcdatamodeld` keeps every shipped 3.x schema:
/// - `SubstrateDataModel 0` (v0, 11 entities): App Store 3.0.1 to 3.8.4, with `CDSingleValue`;
/// - `SubstrateDataModel` (v1, 10 entities): App Store 3.8.5 and the 3.9.0 TestFlight builds;
/// - `SubstrateDataModel 2` (v2, current): an exact copy of App Store 3.8.6 (also 3.8.7 to
///   3.8.9), which added `CDConfig`, `CDMetadataVersion` and `CDNode`.
///
/// Before 3.9.0 the store was opened with RobinHood's `.removeStore`, which deleted it
/// whenever its schema differed from the app's (and whenever its metadata could not be
/// read, for example before the first unlock). An upgrade therefore lost the user's
/// contacts, custom and selected nodes and pool favourites. Now a store from any known
/// version is migrated in place (lightweight migration), and an unrecognized or
/// corrupt store is kept aside for recovery. Unknown errors
/// are retryable. The store holds no key material, but contacts and custom nodes
/// still belong to the user and must never be discarded automatically.
enum SubstrateStoreMigrator {
    static let migrationOptions: [AnyHashable: Any] = [
        NSMigratePersistentStoresAutomaticallyOption: true,
        NSInferMappingModelAutomaticallyOption: true
    ]

    /// Launches in a row on which a readable store kept failing before it is moved aside.
    static let maximumDeferredLaunches = 3
    static let deferredLaunchesKey = "SubstrateStoreMigrator.deferredLaunches"
    /// Pauses before the second and third attempt within one launch, for a store that is
    /// readable but busy or reported an I/O error.
    static let defaultRetryDelays: [TimeInterval] = [0.25, 0.5]

    typealias MetadataReader = (URL) throws -> [String: Any]

    static let defaultMetadataReader: MetadataReader = { url in
        try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url,
            options: nil
        )
    }

    /// Why a launch could not use the store.
    enum DeferralReason: Equatable {
        /// The file cannot be opened at all (before the first unlock) or the bundled
        /// model is missing. Never counted: the store is never moved aside for this.
        case notReadable
        /// The disk is full. Never counted: the user can free space and nothing is lost.
        case noSpace
        /// The file is readable but opening or migrating it failed with a temporary
        /// error (busy, I/O). Retried within the launch and counted across launches.
        case failing
    }

    private enum Attempt {
        case done(SubstrateStorePreparation)
        case deferred(DeferralReason)
    }

    /// `defaults` keeps the count of launches in a row that could not use a readable
    /// store; pass `nil` to never count (and so never move the store aside).
    static func prepare(
        storeURL: URL,
        modelURL: URL,
        defaults: UserDefaults?,
        fileManager: FileManager = .default,
        retryDelays: [TimeInterval] = defaultRetryDelays,
        metadataReader: MetadataReader = defaultMetadataReader,
        logger: LoggerProtocol? = Logger.shared
    ) -> SubstrateStorePreparation {
        func attemptOnce() -> Attempt {
            attempt(
                storeURL: storeURL,
                modelURL: modelURL,
                fileManager: fileManager,
                metadataReader: metadataReader,
                logger: logger
            )
        }

        var outcome = attemptOnce()
        for delay in retryDelays {
            guard case .deferred(.failing) = outcome else { break }
            Thread.sleep(forTimeInterval: delay)
            outcome = attemptOnce()
        }

        switch outcome {
        case let .done(result):
            defaults?.removeObject(forKey: deferredLaunchesKey)
            return result
        case .deferred(.notReadable):
            logger?.warning("Substrate store: not readable now; using a temporary store")
            return .deferred
        case .deferred(.noSpace):
            logger?.warning("Substrate store: the disk is full; using a temporary store")
            return .deferred
        case .deferred(.failing):
            guard let defaults else {
                logger?.warning("Substrate store: could not be opened now; using a temporary store")
                return .deferred
            }
            let launches = defaults.integer(forKey: deferredLaunchesKey) + 1
            if launches >= maximumDeferredLaunches,
               moveAside(storeURL: storeURL, fileManager: fileManager, logger: logger) {
                defaults.removeObject(forKey: deferredLaunchesKey)
                return .movedAside
            }
            defaults.set(launches, forKey: deferredLaunchesKey)
            logger?.warning("Substrate store: could not be opened now (launch \(launches)); using a temporary store")
            return .deferred
        }
    }

    private static func attempt(
        storeURL: URL,
        modelURL: URL,
        fileManager: FileManager,
        metadataReader: MetadataReader,
        logger: LoggerProtocol?
    ) -> Attempt {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            // A -wal, -shm or -journal file without its database is left over from an
            // interrupted removal. SQLite could replay it into the new store, so preserve
            // it outside the active namespace first. It cannot be opened without
            // the database it belonged to.
            return preserveStore(at: storeURL, fileManager: fileManager, logger: logger, result: .ready)
        }

        guard let currentModel = NSManagedObjectModel(contentsOf: modelURL) else {
            logger?.error("Substrate store: the bundled model could not be loaded")
            return .deferred(.notReadable)
        }

        let metadata: [String: Any]
        do {
            metadata = try metadataReader(storeURL)
        } catch {
            switch databaseHeaderState(at: storeURL) {
            case .unreadable:
                return .deferred(.notReadable)
            case .notDatabase:
                return preserveStore(at: storeURL, fileManager: fileManager, logger: logger)
            case .database:
                return outcome(of: error, storeURL: storeURL, fileManager: fileManager, logger: logger)
            }
        }

        if currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
            return .done(.ready)
        }

        let isKnownVersion = knownModels(in: modelURL).contains {
            $0.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
        guard isKnownVersion else {
            return preserveStore(at: storeURL, fileManager: fileManager, logger: logger)
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
            return .done(.migrated)
        } catch {
            // A store from a known version holds the user's contacts and node choices. If
            // it cannot be migrated for a reason that will not pass, keep it aside.
            // A failed move leaves the store for a later attempt; never delete it.
            if classify(error) == .permanent,
               moveAside(storeURL: storeURL, fileManager: fileManager, logger: logger) {
                return .done(.movedAside)
            }
            return outcome(of: error, storeURL: storeURL, fileManager: fileManager, logger: logger)
        }
    }

    private static func outcome(
        of error: Error,
        storeURL: URL,
        fileManager: FileManager,
        logger: LoggerProtocol?
    ) -> Attempt {
        switch classify(error) {
        case .permanent:
            return preserveStore(at: storeURL, fileManager: fileManager, logger: logger)
        case .noSpace:
            return .deferred(.noSpace)
        case .transient:
            return .deferred(.failing)
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

    enum ErrorClass: Equatable {
        /// The store itself is unusable (corrupt, not a database, a schema error).
        case permanent
        /// The disk or quota is full.
        case noSpace
        /// Busy, locked, protected or an I/O error: it can pass.
        case transient
    }

    /// Core Data wraps SQLite failures in generic Cocoa errors (for example 256 for
    /// any read failure) and reports the SQLite result code in `NSSQLiteErrorDomain`.
    /// When a SQLite code is present it decides, because it is the specific report:
    /// SQLITE_CORRUPT and SQLITE_NOTADB are permanent whatever the wrapper says.
    /// Extended codes keep the primary code in the low byte.
    static func classify(_ error: Error) -> ErrorClass {
        let chain = flattened(error)
        let sqliteCodes = chain.compactMap { sqliteCode(of: $0) }.map { $0 & 0xFF }

        if sqliteCodes.contains(where: { permanentSQLiteCodes.contains($0) }) {
            return .permanent
        }
        if sqliteCodes.contains(sqliteFull) || chain.contains(where: { isNoSpace($0) }) {
            return .noSpace
        }
        // An unrecognized error does not establish corruption. Preserve the
        // store and retry, including new SQLite/Cocoa error codes.
        return .transient
    }

    /// "Not now" rather than "never".
    static func isTransient(_ error: Error) -> Bool {
        classify(error) != .permanent
    }

    private static func flattened(_ error: Error) -> [NSError] {
        var result: [NSError] = []
        var pending: [NSError] = [error as NSError]
        while let next = pending.popLast(), result.count < 16 {
            result.append(next)
            if let underlying = next.userInfo[NSUnderlyingErrorKey] as? NSError {
                pending.append(underlying)
            }
            if let detailed = next.userInfo[NSDetailedErrorsKey] as? [NSError] {
                pending.append(contentsOf: detailed)
            }
        }
        return result
    }

    private static func sqliteCode(of error: NSError) -> Int? {
        if error.domain == sqliteErrorDomain {
            return error.code
        }
        return (error.userInfo[sqliteErrorDomain] as? NSNumber)?.intValue
    }

    private static func isNoSpace(_ error: NSError) -> Bool {
        switch error.domain {
        case NSPOSIXErrorDomain:
            return error.code == Int(ENOSPC) || error.code == Int(EDQUOT)
        case NSCocoaErrorDomain:
            return error.code == NSFileWriteOutOfSpaceError
        default:
            return false
        }
    }

    private static let sqliteErrorDomain = "NSSQLiteErrorDomain"

    /// SQLITE_CORRUPT, SQLITE_NOTADB.
    private static let permanentSQLiteCodes: Set<Int> = [11, 26]
    /// SQLITE_FULL.
    private static let sqliteFull = 13
    /// The files that make up one SQLite store, side files first: the database is
    /// moved last, so a failed move leaves its database in place.
    private static let storeFileSuffixes = ["-wal", "-shm", "-journal", ""]

    private static func preserveStore(
        at storeURL: URL,
        fileManager: FileManager,
        logger: LoggerProtocol?,
        result: SubstrateStorePreparation = .movedAside
    ) -> Attempt {
        guard storeFileSuffixes.contains(where: {
            fileManager.fileExists(atPath: storeURL.path + $0)
        }) else { return .done(.ready) }
        guard moveAside(storeURL: storeURL, fileManager: fileManager, logger: logger) else {
            return .deferred(.failing)
        }
        return .done(result)
    }

    /// Renames the store files to `<name>-unreadable-<date>.<ext>` beside it. Nothing is
    /// deleted. If one rename fails, the renames already done are undone.
    static func moveAside(storeURL: URL, fileManager: FileManager, logger: LoggerProtocol?) -> Bool {
        let directory = storeURL.deletingLastPathComponent()
        let base = storeURL.deletingPathExtension().lastPathComponent
        let ext = storeURL.pathExtension
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        var asideName = "\(base)-unreadable-\(formatter.string(from: Date()))"
        let isTaken: (String) -> Bool = { name in
            storeFileSuffixes.contains {
                fileManager.fileExists(atPath: directory.appendingPathComponent("\(name).\(ext)").path + $0)
            }
        }
        if isTaken(asideName) {
            asideName += "-\(UUID().uuidString.prefix(8))"
        }
        let aside = directory.appendingPathComponent("\(asideName).\(ext)")

        var moved: [String] = []
        for suffix in storeFileSuffixes where fileManager.fileExists(atPath: storeURL.path + suffix) {
            do {
                try fileManager.moveItem(atPath: storeURL.path + suffix, toPath: aside.path + suffix)
                moved.append(suffix)
            } catch {
                for done in moved.reversed() {
                    try? fileManager.moveItem(atPath: aside.path + done, toPath: storeURL.path + done)
                }
                logger?.warning("Substrate store: the failing store could not be moved aside now")
                return false
            }
        }
        logger?.warning("Substrate store: a store that kept failing was moved aside; starting a new one")
        return true
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
            databaseName: "\(modelName).sqlite",
            defaults: .standard
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
        defaults: UserDefaults?,
        fileManager: FileManager = .default,
        retryDelays: [TimeInterval] = SubstrateStoreMigrator.defaultRetryDelays
    ) -> (configuration: CoreDataServiceConfiguration, preparation: SubstrateStorePreparation) {
        let storeURL = databaseDirectory.appendingPathComponent(databaseName)
        let preparation = SubstrateStoreMigrator.prepare(
            storeURL: storeURL,
            modelURL: modelURL,
            defaults: defaults,
            fileManager: fileManager,
            retryDelays: retryDelays
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
