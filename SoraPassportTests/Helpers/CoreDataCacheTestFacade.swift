/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
@testable import SoraPassport
import RobinHood
import CoreData

final class CoreDataCacheTestFacade: CoreDataCacheFacadeProtocol {
    let databaseService: CoreDataServiceProtocol

    init() {
        let modelName = "Entities"
        let bundle = Bundle(for: CoreDataCacheFacade.self)
        let modelURL = bundle.url(forResource: modelName, withExtension: "momd")

        let configuration = CoreDataServiceConfiguration(modelURL: modelURL!,
                                                         storageType: .inMemory)

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
