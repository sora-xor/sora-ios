/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import CoreData
import RobinHood

public protocol CoreDataCacheFacadeProtocol: AnyObject {
    var databaseService: CoreDataServiceProtocol { get }

    func createCoreDataCache<T, U>(filter: NSPredicate?) -> CoreDataRepository<T, U>
        where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable
}

public final class CoreDataCacheFacade: CoreDataCacheFacadeProtocol {
    public static let shared = CoreDataCacheFacade()

    public let databaseService: CoreDataServiceProtocol

    private init() {
        let modelName = "CapitalCache"
        let bundle = Bundle(for: type(of: self))
        let modelURL = bundle.url(forResource: modelName, withExtension: "momd")
        let baseURL = FileManager.default.urls(for: .cachesDirectory,
                                               in: .userDomainMask).first?.appendingPathComponent(modelName)

        let persistentSettings = CoreDataPersistentSettings(databaseDirectory: baseURL!,
                                                            databaseName: modelName,
                                                            incompatibleModelStrategy: .removeStore)

        let configuration = CoreDataServiceConfiguration(modelURL: modelURL!,
                                                         storageType: .persistent(settings: persistentSettings))
        databaseService = CoreDataService(configuration: configuration)
    }

    public func createCoreDataCache<T, U>(filter: NSPredicate?) -> CoreDataRepository<T, U>
        where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {

            let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
            return CoreDataRepository(databaseService: databaseService,
                                      mapper: mapper,
                                      filter: filter)
    }
}
