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
import SoraFoundation

/**
 *  Class is designed to handle creation of `ChainRegistryProtocol` instance for application.
 *
 *  Here is list of important config settings applied:
 *  - common and chain types are saved to `Caches` (if unavailable then `tmp` is used)
 *      in `runtime` directory;
 *  - `OperationManagerFacade.runtimeBuildingQueue` queue is used for chain registry
 *      to perform operations faster with `userInitiated` quality of service.
 */

final class ChainRegistryFactory {
    /**
     *  Creates chain registry with on-disk database manager. This function must be used by the application
     *  by default.
     *
     *  - Returns: new instance conforming to `ChainRegistryProtocol`.
     */

    static func createDefaultRegistry() -> ChainRegistryProtocol {
        let repositoryFacade = SubstrateDataStorageFacade.shared
        return createDefaultRegistry(from: repositoryFacade)
    }

    // swiftlint:disable function_body_length

    /**
     *  Creates chain registry with provided database manager. This function must be used when
     *  there is a need to override `createDefaultRegistry()` behavior that stores database on disk.
     *  For example, in tests it is more conveinent to use in-memory database.
     *
     *  - Parameters:
     *      - repositoryFacade: Database manager to use for chain registry.
     *
     *  - Returns: new instance conforming to `ChainRegistryProtocol`.
     */
    static func createDefaultRegistry(
        from repositoryFacade: StorageFacadeProtocol
    ) -> ChainRegistryProtocol {
        let runtimeMetadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            repositoryFacade.createRepository()

        let dataFetchOperationFactory = DataOperationFactory()

        let filesOperationFactory = createFilesOperationFactory()

        let runtimeSyncService = RuntimeSyncService(
            repository: AnyDataProviderRepository(runtimeMetadataRepository),
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataFetchOperationFactory,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )

        let runtimeProviderFactory = RuntimeProviderFactory(
            fileOperationFactory: filesOperationFactory,
            repository: AnyDataProviderRepository(runtimeMetadataRepository),
            dataOperationFactory: dataFetchOperationFactory,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.runtimeBuildingQueue,
            logger: Logger.shared
        )

        let runtimeProviderPool = RuntimeProviderPool(runtimeProviderFactory: runtimeProviderFactory)

        let connectionPool = ConnectionPool(connectionFactory: ConnectionFactory(logger: Logger.shared))

        let chainRepositoryFactory = ChainRepositoryFactory(storageFacade: repositoryFacade)
        let chainRepository = chainRepositoryFactory.createRepository()
        let chainProvider = createChainProvider(from: repositoryFacade, chainRepository: chainRepository)

        let chainSyncService = ChainSyncService(
            typesUrl: ApplicationConfig.shared.commonTypesURL,
            assetsUrl: ApplicationConfig.shared.assetListURL,
            dataFetchFactory: dataFetchOperationFactory,
            repository: AnyDataProviderRepository(chainRepository),
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.runtimeBuildingQueue,
            storeRepair: ChainStoreRepair(databaseService: repositoryFacade.databaseService),
            logger: Logger.shared
        )

        let specVersionSubscriptionFactory = SpecVersionSubscriptionFactory(
            runtimeSyncService: runtimeSyncService,
            logger: Logger.shared
        )

        let commonTypesSyncService = CommonTypesSyncService(
            url: ConfigService.shared.config.typesURL,
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataFetchOperationFactory,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.runtimeBuildingQueue,
            usesReviewedSoraBundle: true
        )

        let snapshotHotBootBuilder = SnapshotHotBootBuilder(
            runtimeProviderPool: runtimeProviderPool,
            chainRepository: AnyDataProviderRepository(chainRepository),
            filesOperationFactory: filesOperationFactory,
            runtimeItemRepository: AnyDataProviderRepository(runtimeMetadataRepository),
            operationQueue: OperationManagerFacade.runtimeBuildingQueue,
            logger: Logger.shared
        )

        let window = UIApplication.shared.soraStatusPresentableWindow
        let networkStatusPresenter = NetworkAvailabilityLayerPresenter()
        networkStatusPresenter.localizationManager = LocalizationManager.shared
        networkStatusPresenter.view = window

        return ChainRegistry(
            snapshotHotBootBuilder: snapshotHotBootBuilder,
            runtimeProviderPool: runtimeProviderPool,
            connectionPool: connectionPool,
            chainSyncService: chainSyncService,
            runtimeSyncService: runtimeSyncService,
            commonTypesSyncService: commonTypesSyncService,
            chainProvider: chainProvider,
            specVersionSubscriptionFactory: specVersionSubscriptionFactory,
            logger: Logger.shared,
            eventCenter: EventCenter.shared,
            chainRepository: AnyDataProviderRepository(ChainRepositoryFactory().createRepository()),
            operationManager: OperationManager(operationQueue: OperationManagerFacade.runtimeBuildingQueue),
            networkStatusPresenter: networkStatusPresenter
        )
    }

    // swiftlint:enable function_body_length

    private static func createFilesOperationFactory() -> RuntimeFilesOperationFactoryProtocol {
        let topDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
        let runtimeDirectory = topDirectory.appendingPathComponent("runtime").path
        return RuntimeFilesOperationFactory(
            repository: FileRepository(),
            directoryPath: runtimeDirectory
        )
    }

    private static func createChainProvider(
        from repositoryFacade: StorageFacadeProtocol,
        chainRepository: CoreDataRepository<ChainModel, CDChain>
    ) -> StreamableProvider<ChainModel> {
        let chainObserver = CoreDataContextObservable(
            service: repositoryFacade.databaseService,
            mapper: chainRepository.dataMapper,
            predicate: { _ in true }
        )

        chainObserver.start { error in
            if error != nil {
                Logger.shared.error("Chain database observation failed")
            }
        }

        return StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource<ChainModel>()),
            repository: AnyDataProviderRepository(chainRepository),
            observable: AnyDataProviderRepositoryObservable(chainObserver),
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}
