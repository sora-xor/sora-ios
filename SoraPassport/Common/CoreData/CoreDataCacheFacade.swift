/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood
import CoreData

protocol CoreDataCacheFacadeProtocol: class {
    var databaseService: CoreDataServiceProtocol { get }

    func createCoreDataCache<T, U>(domain: String) -> CoreDataCache<T, U>
        where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable
}

final class CoreDataCacheFacade: CoreDataCacheFacadeProtocol {
    static let shared = CoreDataCacheFacade()

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

    func createCoreDataCache<T, U>(domain: String) -> CoreDataCache<T, U>
        where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {

            let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
            return CoreDataCache(databaseService: databaseService,
                                 mapper: mapper,
                                 domain: domain)
    }
}
