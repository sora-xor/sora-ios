// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import CoreData
import SQLite3

extension NSPersistentStoreCoordinator {
    static func replaceStore(at targetURL: URL, withStoreAt sourceURL: URL) throws {
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(
            managedObjectModel: NSManagedObjectModel()
        )

        try persistentStoreCoordinator.replacePersistentStore(
            at: targetURL,
            destinationOptions: nil,
            withPersistentStoreFrom: sourceURL,
            sourceOptions: nil,
            ofType: NSSQLiteStoreType
        )
    }

    static func metadata(at storeURL: URL) -> [String: Any]? {
        try? readOnlyMetadata(at: storeURL)
    }

    static func readOnlyMetadata(at storeURL: URL) throws -> [String: Any] {
        // iOS 17's Core Data metadata API initializes unknown SQLite files
        // even with NSReadOnlyPersistentStoreOption. Read the stored metadata
        // directly through a genuinely read-only connection, including WAL
        // pages, so probing never creates a database or rewrites its contents.
        var database: OpaquePointer?
        let opened = sqlite3_open_v2(storeURL.path, &database,
                                    SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_NOFOLLOW, nil)
        defer { if let database { sqlite3_close(database) } }
        guard opened == SQLITE_OK, let database else { throw CocoaError(.fileReadCorruptFile) }
        sqlite3_limit(database, SQLITE_LIMIT_LENGTH, 1_048_576)
        var statement: OpaquePointer?
        defer { if let statement { sqlite3_finalize(statement) } }
        guard sqlite3_prepare_v2(database, "SELECT Z_UUID, Z_PLIST FROM Z_METADATA LIMIT 2",
                                 -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW,
              sqlite3_column_type(statement, 0) == SQLITE_TEXT,
              (1...128).contains(Int(sqlite3_column_bytes(statement, 0))),
              let uuidBytes = sqlite3_column_text(statement, 0),
              sqlite3_column_type(statement, 1) == SQLITE_BLOB,
              (1...1_048_576).contains(Int(sqlite3_column_bytes(statement, 1))),
              let plistBytes = sqlite3_column_blob(statement, 1) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let uuid = String(data: Data(bytes: uuidBytes, count: Int(sqlite3_column_bytes(statement, 0))),
                                encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        let data = Data(bytes: plistBytes, count: Int(sqlite3_column_bytes(statement, 1)))
        guard UUID(uuidString: uuid) != nil,
              sqlite3_step(statement) == SQLITE_DONE,
              var metadata = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              metadata[NSStoreTypeKey] as? String == NSSQLiteStoreType,
              let hashes = metadata[NSStoreModelVersionHashesKey] as? [String: Data], !hashes.isEmpty,
              metadata[NSStoreUUIDKey] == nil || metadata[NSStoreUUIDKey] as? String == uuid else {
            throw CocoaError(.fileReadCorruptFile)
        }
        metadata[NSStoreUUIDKey] = uuid
        return metadata
    }

    func addPersistentStore(at storeURL: URL, options: [AnyHashable: Any]) throws -> NSPersistentStore {
        try addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )
    }
}
