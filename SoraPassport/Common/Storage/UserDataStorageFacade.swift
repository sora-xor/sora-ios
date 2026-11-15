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
import RobinHood
import CoreData

enum UserStorageParams {
    static let modelVersion: UserStorageVersion = .version2
    static let modelDirectory: String = "UserDataModel.momd"
    static let databaseName = "UserDataModel.sqlite"
    // This is a production wallet-identity boundary. RobinHood's `.removeStore`
    // strategy deletes an incompatible SQLite store before Core Data opens it,
    // so the authoritative wallet database must remain fail-closed here.
    static let incompatibleModelStrategy: IncompatibleModelHandlingStrategy = .ignore

    static let storageDirectoryURL: URL = {
        let baseURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("CoreData")

        return baseURL!
    }()

    static var storageURL: URL {
        storageDirectoryURL.appendingPathComponent(databaseName)
    }

    /// The first compiled form of a model that actually loads. `.omo` is only
    /// Core Data's optimised copy of `.mom`. An `.omo` this iOS version cannot
    /// read must not make every wallet database look like an unknown one.
    static func loadableModel(
        forResource resource: String,
        modelDirectory: String = UserStorageParams.modelDirectory,
        bundle: Bundle = .main
    ) -> (url: URL, model: NSManagedObjectModel)? {
        for fileExtension in ["omo", "mom"] {
            guard
                let url = bundle.url(
                    forResource: resource,
                    withExtension: fileExtension,
                    subdirectory: modelDirectory
                ),
                let model = NSManagedObjectModel(contentsOf: url)
            else { continue }
            return (url, model)
        }
        return nil
    }
}

class UserDataStorageFacade: StorageFacadeProtocol {
    static let shared = UserDataStorageFacade()

    let databaseService: CoreDataServiceProtocol

    private init() {
        let modelName = UserStorageParams.modelVersion.rawValue
        let modelURL = UserStorageParams.loadableModel(forResource: modelName)?.url

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: UserStorageParams.storageDirectoryURL,
            databaseName: UserStorageParams.databaseName,
            incompatibleModelStrategy: UserStorageParams.incompatibleModelStrategy
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL!,
            storageType: .persistent(settings: persistentSettings)
        )

        databaseService = CoreDataService(configuration: configuration)
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
