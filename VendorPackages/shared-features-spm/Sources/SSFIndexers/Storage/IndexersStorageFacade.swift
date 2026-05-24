import CoreData
import Foundation
import RobinHood

public enum IndexersStorageFacadeError: Error {
    case coreDataUrlMissed
}

public final class IndexersStorageFacade: StorageFacade {
    public var databaseService: CoreDataServiceProtocol

    public init() throws {
        guard let baseURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("CoreData"),
            let modelURL = Bundle.module.url(
                forResource: "IndexersDataModel",
                withExtension: "momd"
            ) else
        {
            throw IndexersStorageFacadeError.coreDataUrlMissed
        }

        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
        ]

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: baseURL,
            databaseName: "IndexersDataModel.sqlite",
            incompatibleModelStrategy: .removeStore,
            options: options
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL,
            storageType: .persistent(settings: persistentSettings)
        )

        databaseService = CoreDataService(configuration: configuration)
    }

    public func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> AsyncCoreDataRepositoryDefault<T, U> {
        AsyncCoreDataRepositoryDefault(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }
}
