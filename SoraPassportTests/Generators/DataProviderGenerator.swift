/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import CoreData
import RobinHood
@testable import SoraPassport

func createDefaultCoreDataCache<T, U>() -> CoreDataCache<T, U>
    where T: Identifiable & Codable, U: NSManagedObject & CoreDataCodable {
        let coreDataService = CoreDataCacheFacade.shared.databaseService
        let mapper = AnyCoreDataMapper(CodableCoreDataMapper<T, U>())

        return CoreDataCache(databaseService: coreDataService,
                             mapper: mapper)
}

func createDataSourceMock<T>(base: Any, returns items: [T]) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> BaseOperation<[T]> = { _ in
        let pageOperation = BaseOperation<[T]>()
        pageOperation.result = .success(items)

        return pageOperation
    }

    let fetchByIdBlock: (String) -> BaseOperation<T?> = { _ in
        let identifierOperation = BaseOperation<T?>()
        identifierOperation.result = .success(nil)

        return identifierOperation
    }

    return AnyDataProviderSource(base: base,
                                 fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createDataSourceMock<T>(base: Any, returns error: Error) -> AnyDataProviderSource<T> {
    let fetchPageBlock: (UInt) -> BaseOperation<[T]> = { _ in
        let pageOperation = BaseOperation<[T]>()
        pageOperation.result = .error(error)

        return pageOperation
    }

    let fetchByIdBlock: (String) -> BaseOperation<T?> = { _ in
        let identifierOperation = BaseOperation<T?>()
        identifierOperation.result = .error(error)

        return identifierOperation
    }

    return AnyDataProviderSource(base: base,
                                 fetchByPage: fetchPageBlock,
                                 fetchById: fetchByIdBlock)
}

func createSingleValueSourceMock<T>(base: Any, returns item: T) -> AnySingleValueProviderSource<T> {
    let fetch: () -> BaseOperation<T> = {
        let operation = BaseOperation<T>()
        operation.result = .success(item)

        return operation
    }

    return AnySingleValueProviderSource(base: base,
                                        fetch: fetch)
}

func createSingleValueSourceMock<T>(base: Any, returns error: Error) -> AnySingleValueProviderSource<T> {
    let fetch: () -> BaseOperation<T> = {
        let operation = BaseOperation<T>()
        operation.result = .error(error)

        return operation
    }

    return AnySingleValueProviderSource(base: base,
                                        fetch: fetch)
}
