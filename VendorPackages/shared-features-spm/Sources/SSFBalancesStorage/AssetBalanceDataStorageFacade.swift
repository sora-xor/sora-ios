import CoreData
import RobinHood
import SSFUtils

enum AssetBalanceStorageFacadeError: Error {
    case unexpectedError
}

public enum AssetBalanceParams {
    static let modelName = "AssetBalanceModel"
    static let modelDirectory: String = "AssetBalanceModel.momd"
    static let databaseName = "AssetBalanceModel.sqlite"
    public static let momURL = Bundle.module.url(
        forResource: "AssetBalanceModel",
        withExtension: "momd"
    )!

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

public class AssetBalanceDataStorageFacade: StorageFacade {
    public let databaseService: CoreDataServiceProtocol

    public init() {
        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
        ]

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: AssetBalanceParams.storageDirectoryURL,
            databaseName: AssetBalanceParams.databaseName,
            incompatibleModelStrategy: .ignore,
            options: options
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: AssetBalanceParams.momURL,
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
