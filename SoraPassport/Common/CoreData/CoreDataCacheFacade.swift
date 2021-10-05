import Foundation
import RobinHood
import CoreData

protocol CoreDataCacheFacadeProtocol: class {
    var databaseService: CoreDataServiceProtocol {  get }

    func createCoreDataCache<T, U>(filter: NSPredicate?, mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U>
        where T: Identifiable & Codable, U: NSManagedObject
}

extension CoreDataCacheFacadeProtocol {
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

    func createCoreDataCache<T, U>(filter: NSPredicate?, mapper: AnyCoreDataMapper<T, U>)
        -> CoreDataRepository<T, U> where T: Identifiable & Codable, U: NSManagedObject {
            return CoreDataRepository(databaseService: databaseService,
                                      mapper: mapper,
                                      filter: filter)
    }
}
