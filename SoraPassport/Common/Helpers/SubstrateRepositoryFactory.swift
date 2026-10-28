// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import RobinHood
import SSFSingleValueCache

protocol SubstrateRepositoryFactoryProtocol {
    func createChainStorageItemRepository() -> AnyDataProviderRepository<ChainStorageItem>
//    func createStashItemRepository() -> AnyDataProviderRepository<StashItem>
    func createSingleValueRepository() -> AnyDataProviderRepository<SingleValueProviderObject>
}

final class SubstrateRepositoryFactory: SubstrateRepositoryFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared) {
        self.storageFacade = storageFacade
    }

    func createChainStorageItemRepository() -> AnyDataProviderRepository<ChainStorageItem> {
        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return AnyDataProviderRepository(repository)
    }

//    func createStashItemRepository() -> AnyDataProviderRepository<StashItem> {
//        let mapper: CodableCoreDataMapper<StashItem, CDStashItem> =
//            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDStashItem.stash))
//
//        let repository: CoreDataRepository<StashItem, CDStashItem> =
//            storageFacade.createRepository(
//                filter: nil,
//                sortDescriptors: [],
//                mapper: AnyCoreDataMapper(mapper)
//            )
//
//        return AnyDataProviderRepository(repository)
//    }

    func createSingleValueRepository() -> AnyDataProviderRepository<SingleValueProviderObject> {
        let repository = SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()

        return AnyDataProviderRepository(repository)
    }
}
