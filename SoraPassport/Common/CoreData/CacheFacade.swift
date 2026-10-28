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

protocol CacheFacadeProtocol: AnyObject {
    var databaseService: CoreDataServiceProtocol {  get }

    func createCoreDataCache<T, U>(filter: NSPredicate?, mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
        where T: Identifiable & Codable, U: NSManagedObject
}

extension CacheFacadeProtocol {
    func createCoreDataCache<T, U>(mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
    where T: Identifiable & Codable, U: NSManagedObject {
        return createCoreDataCache(filter: nil, mapper: mapper)
    }

    func createCoreDataCache<T, U>() -> CoreDataRepository<T, U>
    where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createCoreDataCache(filter: nil, mapper: mapper)
    }
}

final class CacheFacade: CacheFacadeProtocol {
    static let shared = CacheFacade()

    let databaseService: CoreDataServiceProtocol

    private init() {
        let modelName = "Entities"
        let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd")
        let databaseName = "\(modelName).sqlite"

        let baseURL = FileManager.default.urls(for: .cachesDirectory,
                                               in: .userDomainMask).first?.appendingPathComponent("CoreData")

        let persistentSettings = CoreDataPersistentSettings(databaseDirectory: baseURL!,
                                                            databaseName: databaseName,
                                                            incompatibleModelStrategy: .removeStore)

        let configuration = CoreDataServiceConfiguration(modelURL: modelURL!,
                                                         storageType: .persistent(settings: persistentSettings))

        databaseService = CoreDataService(configuration: configuration)
    }

    func createCoreDataCache<T, U>(filter: NSPredicate?, mapper: AnyCoreDataMapper<T, U>)
        -> CoreDataRepository<T, U> where T: Identifiable & Codable, U: NSManagedObject {
            return CoreDataRepository(databaseService: databaseService,
                                      mapper: mapper,
                                      filter: filter)
    }
}
