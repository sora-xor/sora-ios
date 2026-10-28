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

protocol SubstrateDataProviderFactoryProtocol {
    func createRuntimeMetadataItemProvider(for chain: Chain) -> StreamableProvider<RuntimeMetadataItem>
    func createStorageProvider(for key: String) -> StreamableProvider<ChainStorageItem>
}

final class SubstrateDataProviderFactory: SubstrateDataProviderFactoryProtocol {
    let facade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    init(facade: StorageFacadeProtocol,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol? = nil) {
        self.facade = facade
        self.operationManager = operationManager
        self.logger = logger
    }

    func createRuntimeMetadataItemProvider(for chain: Chain) -> StreamableProvider<RuntimeMetadataItem> {
        let identifier = chain.genesisHash()

        let filter = NSPredicate.filterRuntimeMetadataItemsBy(identifier: identifier)
        let storage: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            facade.createRepository(filter: filter)
        let source = EmptyStreamableSource<RuntimeMetadataItem>()
        let observable = CoreDataContextObservable(service: facade.databaseService,
                                                   mapper: AnyCoreDataMapper(storage.dataMapper),
                                                   predicate: { $0.identifier == identifier })

        observable.start { error in
            if error != nil {
                self.logger?.error("Storage observation failed to start")
            }
        }

        return StreamableProvider(source: AnyStreamableSource(source),
                                  repository: AnyDataProviderRepository(storage),
                                  observable: AnyDataProviderRepositoryObservable(observable),
                                  operationManager: operationManager)
    }

    func createStorageProvider(for key: String) -> StreamableProvider<ChainStorageItem> {
        let filter = NSPredicate.filterStorageItemsBy(identifier: key)
        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            facade.createRepository(filter: filter)
        let source = EmptyStreamableSource<ChainStorageItem>()
        let observable = CoreDataContextObservable(service: facade.databaseService,
                                                   mapper: AnyCoreDataMapper(storage.dataMapper),
                                                   predicate: { $0.identifier == key })

        observable.start { error in
            if error != nil {
                self.logger?.error("Storage observation failed to start")
            }
        }

        return StreamableProvider(source: AnyStreamableSource(source),
                                  repository: AnyDataProviderRepository(storage),
                                  observable: AnyDataProviderRepositoryObservable(observable),
                                  operationManager: operationManager)
    }
}
