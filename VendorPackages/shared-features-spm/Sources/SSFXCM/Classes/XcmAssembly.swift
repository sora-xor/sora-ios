import Foundation
import RobinHood
import SSFAssetManagment
import SSFAssetManagmentStorage
import SSFChainConnection
import SSFChainRegistry
import SSFCrypto
import SSFExtrinsicKit
import SSFModels
import SSFNetwork
import SSFRuntimeCodingService
import SSFSigner
import SSFStorageQueryKit
import SSFUtils

public struct XcmExtrinsicServices {
    public let extrinsic: XcmExtrinsicServiceProtocol
    public let destinationFeeFetcher: XcmDestinationFeeFetching
    public let availableDestionationFetching: XcmChainsConfigFetching
}

public enum XcmAssembly {
    public static func createExtrincisServices(
        fromChainData: FromChainData,
        sourceConfig: XcmConfigProtocol?
    ) -> XcmExtrinsicServices {
        let signingWrapper = TransactionSignerAssembly.signer(
            for: fromChainData.chainType,
            publicKeyData: fromChainData.signingWrapperData.publicKeyData,
            secretKeyData: fromChainData.signingWrapperData.secretKeyData,
            cryptoType: fromChainData.cryptoType
        )

        let extrinsicBuilder = XcmExtrinsicBuilder()

        let mapper = ChainModelMapper()

        let repository: AsyncCoreDataRepositoryDefault<ChainModel, CDChain> =
            SubstrateDataStorageFacade()!.createAsyncRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let service = LocalChainModelServiceDefault(repository: AsyncAnyRepository(repository))

        let chainSyncService = ChainsDataFetcher(
            chainsUrl: sourceConfig?.chainsSourceUrl ?? XcmConfig.shared.chainsSourceUrl,
            operationQueue: OperationQueue(),
            dataFetchFactory: NetworkOperationFactory(),
            localeChainService: service
        )

        let chainsTypesSyncService = ChainTypesRemoteDataFercher(
            url: sourceConfig?.chainTypesSourceUrl ?? XcmConfig.shared.chainTypesSourceUrl,
            dataOperationFactory: NetworkOperationFactory(),
            operationQueue: OperationQueue()
        )

        let runtimeSyncService = RuntimeSyncService(dataOperationFactory: NetworkOperationFactory())

        let chainRegistry = ChainRegistry(
            runtimeProviderPool: RuntimeProviderPool(),
            connectionPool: ConnectionPool(),
            chainsDataFetcher: chainSyncService,
            chainsTypesDataFetcher: chainsTypesSyncService,
            runtimeSyncService: runtimeSyncService
        )

        let xcmChainsConfigFetcher = XcmChainsConfigFetcher(chainRegistry: chainRegistry)
        let depsContainer = XcmDependencyContainer(
            chainRegistry: chainRegistry,
            fromChainData: fromChainData
        )

        let callPathDeterminer = CallPathDeterminerImpl(
            chainRegistry: chainRegistry,
            fromChainData: fromChainData
        )

        let destinationFeeFetcher = XcmDestinationFeeFetcher(
            sourceUrl: sourceConfig?.destinationFeeSourceUrl ?? XcmConfig.shared
                .destinationFeeSourceUrl,
            networkOperationFactory: NetworkOperationFactory(),
            operationQueue: OperationQueue()
        )

        let extrinsic = XcmExtrinsicService(
            signingWrapper: signingWrapper,
            extrinsicBuilder: extrinsicBuilder,
            xcmVersionFetcher: xcmChainsConfigFetcher,
            chainRegistry: chainRegistry,
            depsContainer: depsContainer,
            callPathDeterminer: callPathDeterminer,
            xcmFeeFetcher: destinationFeeFetcher
        )

        return XcmExtrinsicServices(
            extrinsic: extrinsic,
            destinationFeeFetcher: destinationFeeFetcher,
            availableDestionationFetching: xcmChainsConfigFetcher
        )
    }
}

public extension XcmAssembly {
    struct SigningWrapperData: Equatable {
        public let publicKeyData: Data
        public let secretKeyData: Data

        public init(publicKeyData: Data, secretKeyData: Data) {
            self.publicKeyData = publicKeyData
            self.secretKeyData = secretKeyData
        }
    }

    struct FromChainData {
        public let chainId: String
        public let cryptoType: CryptoType
        public let chainMetadata: RuntimeMetadataItemProtocol?
        public let accountId: AccountId
        public let signingWrapperData: SigningWrapperData
        public let chainType: ChainBaseType

        public init(
            chainId: String,
            cryptoType: CryptoType,
            chainMetadata: RuntimeMetadataItemProtocol?,
            accountId: AccountId,
            signingWrapperData: XcmAssembly.SigningWrapperData,
            chainType: ChainBaseType
        ) {
            self.chainId = chainId
            self.cryptoType = cryptoType
            self.chainMetadata = chainMetadata
            self.accountId = accountId
            self.signingWrapperData = signingWrapperData
            self.chainType = chainType
        }
    }
}
