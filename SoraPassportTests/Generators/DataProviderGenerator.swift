import Foundation
import CoreData
import RobinHood
@testable import SoraPassport

func createDefaultCoreDataCache<T, U>() -> CoreDataRepository<T, U>
    where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let coreDataService = CoreDataCacheFacade.shared.databaseService
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())

        return CoreDataRepository(databaseService: coreDataService, mapper: mapper)
}

func createDataSourceMock<T>(returns items: [T]) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> CompoundOperationWrapper<[T]> = { _ in
        let pageOperation = BaseOperation<[T]>()
        pageOperation.result = .success(items)

        return CompoundOperationWrapper(targetOperation: pageOperation)
    }

    let fetchByIdBlock: (String) -> CompoundOperationWrapper<T?> = { _ in
        let identifierOperation = BaseOperation<T?>()
        identifierOperation.result = .success(nil)

        return CompoundOperationWrapper(targetOperation: identifierOperation)
    }

    return AnyDataProviderSource(fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createDataSourceMock<T>(returns error: Error) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> CompoundOperationWrapper<[T]> = { _ in
        let pageOperation = BaseOperation<[T]>()
        pageOperation.result = .failure(error)

        return CompoundOperationWrapper(targetOperation: pageOperation)
    }

    let fetchByIdBlock: (String) -> CompoundOperationWrapper<T?> = { _ in
        let identifierOperation = BaseOperation<T?>()
        identifierOperation.result = .failure(error)

        return CompoundOperationWrapper(targetOperation: identifierOperation)
    }

    return AnyDataProviderSource(fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createSingleValueSourceMock<T>(returns item: T) -> AnySingleValueProviderSource<T> {
    let fetch: () -> CompoundOperationWrapper<T?> = {
        let operation = BaseOperation<T?>()
        operation.result = .success(item)

        return CompoundOperationWrapper(targetOperation: operation)
    }

    return AnySingleValueProviderSource(fetch: fetch)
}

func createSingleValueSourceMock<T>(returns error: Error) -> AnySingleValueProviderSource<T> {
    let fetch: () -> CompoundOperationWrapper<T?> = {
        let operation = BaseOperation<T?>()
        operation.result = .failure(error)

        return CompoundOperationWrapper(targetOperation: operation)
    }

    return AnySingleValueProviderSource(fetch: fetch)
}
