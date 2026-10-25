import Foundation
import RobinHood

public typealias IndexersRepository = AsyncCoreDataRepositoryDefault<
    TransactionHistoryItem,
    CDTransactionHistoryItem
>

public protocol IndexersRepositoryAssembly {
    func createRepository() throws -> IndexersRepository
}

public final class IndexersRepositoryAssemblyDefault: IndexersRepositoryAssembly {
    public init() {}

    public func createRepository() throws -> IndexersRepository {
        try IndexersStorageFacade().createRepository()
    }
}
