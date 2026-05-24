import Foundation
import RobinHood
import SSFAssetManagment
import SSFAssetManagmentStorage
import SSFModels
import SSFNetwork
import SSFUtils

public enum ChainRegistryAssembly {
    public static func createDefaultRegistry(
        chainsUrl: URL = ApplicationSourcesImpl.shared.chainsSourceUrl,
        chainTypesUrls: URL = ApplicationSourcesImpl.shared.chainTypesSourceUrl
    ) -> ChainRegistryProtocol {
        let mapper = ChainModelMapper()

        let repository: AsyncCoreDataRepositoryDefault<ChainModel, CDChain> =
            SubstrateDataStorageFacade()!.createAsyncRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let service = LocalChainModelServiceDefault(repository: AsyncAnyRepository(repository))

        let chainsDataFetcher = ChainsDataFetcher(
            chainsUrl: chainsUrl,
            operationQueue: OperationQueue(),
            dataFetchFactory: NetworkOperationFactory(),
            localeChainService: service
        )

        let chainsTypesDataFetcher = ChainTypesRemoteDataFercher(
            url: chainTypesUrls,
            dataOperationFactory: NetworkOperationFactory(),
            operationQueue: OperationQueue()
        )

        let runtimeSyncService = RuntimeSyncService(dataOperationFactory: NetworkOperationFactory())

        let chainRegistry = ChainRegistry(
            runtimeProviderPool: RuntimeProviderPool(),
            connectionPool: ConnectionPool(),
            chainsDataFetcher: chainsDataFetcher,
            chainsTypesDataFetcher: chainsTypesDataFetcher,
            runtimeSyncService: runtimeSyncService
        )

        return chainRegistry
    }
}
