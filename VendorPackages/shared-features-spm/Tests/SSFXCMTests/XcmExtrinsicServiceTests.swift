import BigInt
import RobinHood
import SSFExtrinsicKit
import SSFModels
import SSFRuntimeCodingService
import SSFSigner
import SSFUtils
import XCTest

@testable import SSFXCM

final class XcmExtrinsicServiceTests: XCTestCase {
    var service: XcmExtrinsicServiceProtocol?
    var extrinsicBuilder: XcmExtrinsicBuilderProtocolMock?
    var versionFetcher: XcmVersionFetchingMock?
    var chainRegistry: ChainRegistryProtocolMock?
    var depsContainer: XcmDependencyContainerProtocolMock?
    var determiner: CallPathDeterminerMock?
    var feeFetcher: XcmDestinationFeeFetchingMock?

    override func setUp() {
        super.setUp()

        let signingWrapper = TransactionSignerAssembly.signer(
            for: .substrate,
            publicKeyData: Data(),
            secretKeyData: Data(),
            cryptoType: .sr25519
        )
        let extrinsicBuilder = XcmExtrinsicBuilderProtocolMock()
        let versionFetcher = XcmVersionFetchingMock()
        let chainRegistry = ChainRegistryProtocolMock()
        let depsContainer = XcmDependencyContainerProtocolMock()
        let determiner = CallPathDeterminerMock()
        let feeFetcher = XcmDestinationFeeFetchingMock()

        self.extrinsicBuilder = extrinsicBuilder
        self.versionFetcher = versionFetcher
        self.chainRegistry = chainRegistry
        self.depsContainer = depsContainer
        self.determiner = determiner
        self.feeFetcher = feeFetcher

        setupDependencies()

        service = XcmExtrinsicService(
            signingWrapper: signingWrapper,
            extrinsicBuilder: extrinsicBuilder,
            xcmVersionFetcher: versionFetcher,
            chainRegistry: chainRegistry,
            depsContainer: depsContainer,
            callPathDeterminer: determiner,
            xcmFeeFetcher: feeFetcher
        )
    }

    override func tearDown() {
        super.tearDown()
        extrinsicBuilder = nil
        versionFetcher = nil
        chainRegistry = nil
        depsContainer = nil
        determiner = nil
        feeFetcher = nil
        service = nil
    }

    func testEstimateOriginalFee() async {
        // arrange
        let fromChainId = "0"
        let assetSymbol = "0"
        let destChainId = "0"
        let destAccountId: AccountId = Data()
        let amount = BigUInt()

        for path in TestData.paths {
            determiner?.determineCallPathFromDestReturnValue = path

            // act
            let result = await service?.estimateOriginalFee(
                fromChainId: fromChainId,
                assetSymbol: assetSymbol,
                destChainId: destChainId,
                destAccountId: destAccountId,
                amount: amount
            )
            // assert
            XCTAssertNotNil(result)

            switch result {
            case let .success(info):
                XCTAssertEqual(info.fee, "0")
            case let .failure(error):
                XCTAssertEqual(
                    error.localizedDescription,
                    XcmError.caseNotProcessed.localizedDescription
                )
            case .none:
                XCTFail()
            }
        }
    }

    func testTransfer() async {
        // arrange
        let fromChainId = "0"
        let assetSymbol = "0"
        let destChainId = "0"
        let destAccountId: AccountId = Data()
        let amount = BigUInt()

        for path in TestData.paths {
            determiner?.determineCallPathFromDestReturnValue = path

            // act
            let result = await service?.transfer(
                fromChainId: fromChainId,
                assetSymbol: assetSymbol,
                destChainId: destChainId,
                destAccountId: destAccountId,
                amount: amount
            )
            // assert
            XCTAssertNotNil(result)

            switch result {
            case let .success(value):
                XCTAssertEqual(value, "success")
            case let .failure(error):
                XCTAssertEqual(
                    error.localizedDescription,
                    XcmError.caseNotProcessed.localizedDescription
                )
            case .none:
                XCTFail()
            }
        }
    }
}

private extension XcmExtrinsicServiceTests {
    private enum TestData {
        static let fromChainData = XcmAssembly.FromChainData(
            chainId: "1",
            cryptoType: .ed25519,
            chainMetadata: nil,
            accountId: Data(),
            signingWrapperData: .init(
                publicKeyData: Data(),
                secretKeyData: Data()
            ),
            chainType: .substrate
        )

        static let fromChain = ChainModel(
            rank: 0,
            disabled: false,
            chainId: "0",
            paraId: "1001",
            name: "test1",
            tokens: ChainRemoteTokens(
                type: .config,
                whitelist: nil,
                utilityId: nil,
                tokens: Set(
                    [
                        .init(
                            id: "0",
                            name: "0",
                            symbol: "0",
                            isUtility: true,
                            precision: 0,
                            substrateType: .soraAsset,
                            ethereumType: nil,
                            tokenProperties:
                                TokenProperties(
                                    priceId: "0",
                                    currencyId: "0",
                                    color: "0",
                                    type: .soraAsset,
                                    isNative: true
                                ),
                            price: nil,
                            priceId: nil,
                            coingeckoPriceId: nil,
                            priceProvider: nil
                        ),
                    ]
                )),
            xcm: XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: true,
                availableAssets: [.init(
                    id: "0",
                    symbol: "0"
                )],
                availableDestinations: [.init(
                    chainId: "0",
                    bridgeParachainId: "2",
                    assets: [.init(
                        id: "1",
                        symbol: "1"
                    )]
                )]
            ),
            nodes: Set([ChainNodeModel(
                url: XcmConfig.shared.tokenLocationsSourceUrl,
                name: "test1",
                apikey: nil
            )]),
            icon: nil,
            iosMinAppVersion: nil,
            properties: ChainProperties(addressPrefix: "0")
        )

        static let paths: [XcmCallPath] = [
            .xcmPalletLimitedTeleportAssets,
            .xcmPalletLimitedReserveTransferAssets,
            .polkadotXcmLimitedTeleportAssets,
            .polkadotXcmLimitedReserveTransferAssets,
            .polkadotXcmLimitedReserveWithdrawAssets,
            .xTokensTransferMultiasset,
            .bridgeProxyBurn,
            .parachainId,
        ]

        static let runtimeProvider = RuntimeProvider(
            operationQueue: OperationQueue(),
            usedRuntimePaths: [:],
            chainMetadata: RuntimeMetadataItem(
                chain: "0",
                version: 0,
                txVersion: 0,
                metadata: Data()
            ),
            chainTypes: Data()
        )

        static let connectionChain = WebSocketEngine(
            connectionName: "test",
            url: XcmConfig.shared.chainsSourceUrl
        )
    }

    func setupDependencies() {
        chainRegistry?.getChainForReturnValue = TestData.fromChain
        feeFetcher?.estimateWeightForReturnValue = BigUInt()
        versionFetcher?.getVersionForReturnValue = .V1

        let closure: ExtrinsicBuilderClosure = { $0 }
        extrinsicBuilder?
            .buildReserveNativeTokenExtrinsicBuilderClosureVersionFromChainModelDestChainModelDestAccountIdAmountWeightLimitPathReturnValue =
            closure
        extrinsicBuilder?
            .buildXTokensTransferExtrinsicBuilderClosureVersionAccountIdCurrencyIdDestChainModelAmountWeightLimitPathReturnValue =
            closure
        extrinsicBuilder?
            .buildXTokensTransferMultiassetExtrinsicBuilderClosureAssetSymbolVersionAccountIdFromChainModelDestChainModelAmountWeightLimitPathDestWeightIsPrimitiveReturnValue =
            closure
        extrinsicBuilder?
            .buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosureFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountWeightLimitPathReturnValue =
            closure
        extrinsicBuilder?
            .buildBridgeProxyBurnFromChainModelCurrencyIdDestChainModelAccountIdAmountPathReturnValue =
            closure
        depsContainer?.prepareDepsReturnValue = XcmDeps(extrinsicService: extrinsicService())
    }

    private func extrinsicService() -> ExtrinsicServiceProtocol {
        let extrinsicService = ExtrinsicServiceProtocolMock()
        extrinsicService.estimateFeeRunningInCompletionClosure = { _, _, completion in
            let info = RuntimeDispatchInfo(inclusionFee: .init(
                baseFee: BigUInt(),
                lenFee: BigUInt(),
                adjustedWeightFee: BigUInt()
            ))
            completion(.success(info))
        }

        extrinsicService.submitSignerRunningInCompletionClosure = { _, _, _, completion in
            completion(.success("success"))
        }

        return extrinsicService
    }
}
