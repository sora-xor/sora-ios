import CoreData
import Foundation
import RobinHood
import SSFUtils

enum UserDataStorageFacadeError: Error {
    case unexpectedError
}

public enum UserStorageParams {
    static let modelVersion: UserStorageVersion = .version12
    static let modelDirectory: String = "UserDataModel.momd"
    static let databaseName = "UserDataModel.sqlite"
    public static let momURL = Bundle.module.url(
        forResource: "UserDataModel",
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

public class UserDataStorageFacade: StorageFacadeProtocol {
    public static let shared = UserDataStorageFacade()
    public let databaseService: CoreDataServiceProtocol

    public init?() {
        guard let modelURL = Bundle.module.url(
            forResource: "UserDataModel",
            withExtension: "momd"
        ) else {
            return nil
        }

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: UserStorageParams.storageDirectoryURL,
            databaseName: UserStorageParams.databaseName,
            incompatibleModelStrategy: .ignore
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

    func createStreamableProvider<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> StreamableProvider<T> {
        let repository = createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: mapper
        )

        let observer = CoreDataContextObservable(
            service: databaseService,
            mapper: repository.dataMapper,
            predicate: { _ in true }
        )

        observer.start { _ in }

        return StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource<T>()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observer),
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}
