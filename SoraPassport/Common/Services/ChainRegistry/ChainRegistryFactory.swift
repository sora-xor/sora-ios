// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
            operationQueue: OperationManagerFacade.runtimeBuildingQueue
        )

        let snapshotHotBootBuilder = SnapshotHotBootBuilder(
            runtimeProviderPool: runtimeProviderPool,
            chainRepository: AnyDataProviderRepository(chainRepository),
            filesOperationFactory: filesOperationFactory,
            runtimeItemRepository: AnyDataProviderRepository(runtimeMetadataRepository),
            operationQueue: OperationManagerFacade.runtimeBuildingQueue,
            logger: Logger.shared
        )

        let window = UIApplication.shared.keyWindow as? ApplicationStatusPresentable
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
            if let error = error {
                Logger.shared.error("Chain database observer unexpectedly failed: \(error)")
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
