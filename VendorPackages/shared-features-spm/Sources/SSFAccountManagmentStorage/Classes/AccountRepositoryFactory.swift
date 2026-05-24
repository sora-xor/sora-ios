import Foundation
import IrohaCrypto
import RobinHood
import SSFModels
import SSFUtils

public protocol AccountRepositoryFactoryProtocol {
    func createMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<MetaAccountModel>

    func createManagedMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<ManagedMetaAccountModel>

    func createAsyncMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AsyncAnyRepository<MetaAccountModel>
}

public final class AccountRepositoryFactory: AccountRepositoryFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    public init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    public func createMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<MetaAccountModel> {
        let mapper = MetaAccountMapper()

        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }

    public func createManagedMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<ManagedMetaAccountModel> {
        let mapper = ManagedMetaAccountMapper()

        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }

    public func createAsyncMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AsyncAnyRepository<MetaAccountModel> {
        let mapper = MetaAccountMapper()
        let repository = storageFacade.createAsyncRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )
        return AsyncAnyRepository(repository)
    }
}

extension AccountRepositoryFactory {
    static func createRepository(
        for storageFacade: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<MetaAccountModel> {
        let mapper = MetaAccountMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        return AnyDataProviderRepository(repository)
    }
}
