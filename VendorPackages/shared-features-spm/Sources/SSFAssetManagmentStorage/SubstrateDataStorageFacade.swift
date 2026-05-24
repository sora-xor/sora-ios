import CoreData
import RobinHood
import SSFUtils

enum SubstrateDataStorageFacadeError: Error {
    case unexpectedError
}

public enum SubstrateStorageParams {
    static let modelName = "SubstrateDataModel"
    static let modelVersion: SubstrateStorageVersion = .version5
    static let modelDirectory: String = "SubstrateDataModel.momd"
    static let databaseName = "SubstrateDataModel.sqlite"
    public static let momURL = Bundle.module.url(
        forResource: "SubstrateDataModel",
        withExtension: "momd"
    )

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
}

public class SubstrateDataStorageFacade: StorageFacadeProtocol {
    public static let shared = SubstrateDataStorageFacade()
    public let databaseService: CoreDataServiceProtocol

    public init?() {
        guard let modelURL = Bundle.module.url(
            forResource: "SubstrateDataModel",
            withExtension: "momd"
        ) else {
            return nil
        }

        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
        ]

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: SubstrateStorageParams.storageDirectoryURL,
            databaseName: SubstrateStorageParams.databaseName,
            incompatibleModelStrategy: .ignore,
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
    ) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
        CoreDataRepository(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }

    public func createAsyncRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> AsyncCoreDataRepositoryDefault<T, U> where T: Identifiable, U: NSManagedObject {
        AsyncCoreDataRepositoryDefault(
            databaseService: databaseService,
            mapper: mapper,
            filter: filter,
            sortDescriptors: sortDescriptors
        )
    }
}
