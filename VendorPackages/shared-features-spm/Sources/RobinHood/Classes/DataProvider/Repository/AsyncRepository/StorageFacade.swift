import CoreData
import Foundation

public protocol StorageFacade: AnyObject {
    var databaseService: CoreDataServiceProtocol { get }

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> AsyncCoreDataRepositoryDefault<T, U>
}

public extension StorageFacade {
    func createRepository<T, U>(
    ) -> AsyncCoreDataRepositoryDefault<T, U>
        where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable
    {
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())
        return createRepository(filter: nil, sortDescriptors: [], mapper: mapper)
    }
}
