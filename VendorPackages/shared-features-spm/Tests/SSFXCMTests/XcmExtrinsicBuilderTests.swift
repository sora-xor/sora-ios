import BigInt
import SSFModels
import SSFUtils
import XCTest

@testable import SSFXCM

final class XcmExtrinsicBuilderTests: XCTestCase {
    var builder: XcmExtrinsicBuilderProtocol?
    var callFactory: XcmCallFactoryProtocolMock?

    override func setUp() {
        super.setUp()
        let callFactory = XcmCallFactoryProtocolMock()
        callFactory
            .reserveNativeTokenVersionFromChainModelDestChainModelDestAccountIdAmountWeightLimitPathReturnValue =
            createRuntimeCall(TestData.reserveTransferCall)
        callFactory
            .xTokensTransferVersionAccountIdCurrencyIdDestChainModelAmountWeightLimitPathReturnValue =
            createRuntimeCall(TestData.xTokensTransferCall)
        callFactory
            .xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountWeightLimitPathDestWeightIsPrimitiveReturnValue =
            createRuntimeCall(TestData.xTokenMultiassetCall)
        callFactory
            .polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountWeightLimitPathReturnValue =
            createRuntimeCall(TestData.reserveTransferCall)
        callFactory
            .bridgeProxyBurnFromChainModelCurrencyIdDestChainModelAccountIdAmountPathReturnValue =
            createRuntimeCall(TestData.bridgeProxyCall)

        self.callFactory = callFactory

        builder = XcmExtrinsicBuilder(callFactory: callFactory)
    }

    override func tearDown() {
        super.tearDown()
        callFactory = nil
        builder = nil
    }

    func testBuildReserveNativeTokenExtrinsicBuilderClosure() {
        // arrange
        let version: XcmCallFactoryVersion = .V1
        let destAccountId: AccountId = Data()
        let fromChainModel: ChainModel = TestData.chainModel
        let destChainModel: ChainModel = TestData.chainModel
        let amount = BigUInt()
        let weightLimit = BigUInt()
        let path: XcmCallPath = .parachainId

        // act
        let closure = builder?.buildReserveNativeTokenExtrinsicBuilderClosure(
            version: version,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            destAccountId: destAccountId,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        // assert
        XCTAssertNotNil(closure)
        XCTAssertEqual(
            callFactory?
                .reserveNativeTokenVersionFromChainModelDestChainModelDestAccountIdAmountWeightLimitPathCallsCount,
            1
        )
    }

    func testBuildXTokensTransferExtrinsicBuilderClosure() {
        // arrange
        let version: XcmCallFactoryVersion = .V1
        let accountId: AccountId = Data()
        let currencyId: CurrencyId = .xcm(id: "0")
        let destChainModel: ChainModel = TestData.chainModel
        let amount = BigUInt()
        let weightLimit = BigUInt()
        let path: XcmCallPath = .parachainId

        // act
        let closure = builder?.buildXTokensTransferExtrinsicBuilderClosure(
            version: version,
            accountId: accountId,
            currencyId: currencyId,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        // assert
        XCTAssertNotNil(closure)
        XCTAssertEqual(
            callFactory?
                .xTokensTransferVersionAccountIdCurrencyIdDestChainModelAmountWeightLimitPathCallsCount,
            1
        )
    }

    func testBuildXTokensTransferMultiassetExtrinsicBuilderClosure() async throws {
        // arrange
        let assetSymbol = "0"
        let version: XcmCallFactoryVersion = .V1
        let accountId: AccountId = Data()
        let fromChainModel: ChainModel = TestData.chainModel
        let destChainModel: ChainModel = TestData.chainModel
        let amount = BigUInt()
        let weightLimit = BigUInt()
        let path: XcmCallPath = .parachainId

        // act
        let closure = try await builder?.buildXTokensTransferMultiassetExtrinsicBuilderClosure(
            assetSymbol: assetSymbol,
            version: version,
            accountId: accountId,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path,
            destWeightIsPrimitive: true
        )

        // assert
        XCTAssertNotNil(closure)
        XCTAssertEqual(
            callFactory?
                .xTokensTransferMultiassetVersionAssetSymbolAccountIdFromChainModelDestChainModelAmountWeightLimitPathDestWeightIsPrimitiveCallsCount,
            1
        )
    }

    func testBuildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure() async throws {
        // arrange
        let fromChainModel: ChainModel = TestData.chainModel
        let version: XcmCallFactoryVersion = .V1
        let assetSymbol = "0"
        let accountId: AccountId = Data()
        let destChainModel: ChainModel = TestData.chainModel
        let amount = BigUInt()
        let weightLimit = BigUInt()
        let path: XcmCallPath = .parachainId

        // act
        let closure = try await builder?
            .buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure(
                fromChainModel: fromChainModel,
                version: version,
                assetSymbol: assetSymbol,
                accountId: accountId,
                destChainModel: destChainModel,
                amount: amount,
                weightLimit: weightLimit,
                path: path
            )

        // assert
        XCTAssertNotNil(closure)
        XCTAssertEqual(
            callFactory?
                .polkadotXcmLimitedReserveTransferAssetsFromChainModelVersionAssetSymbolAccountIdDestChainModelAmountWeightLimitPathCallsCount,
            1
        )
    }

    func testBuildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure() throws {
        // arrange
        let fromChainModel: ChainModel = TestData.chainModel
        let currencyId = "0"
        let accountId: AccountId = Data()
        let destChainModel: ChainModel = TestData.chainModel
        let amount = BigUInt()
        let path: XcmCallPath = .parachainId

        // act
        let closure = try builder?.buildBridgeProxyBurn(
            fromChainModel: fromChainModel,
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        )

        // assert
        XCTAssertNotNil(closure)
        XCTAssertEqual(
            callFactory?
                .bridgeProxyBurnFromChainModelCurrencyIdDestChainModelAccountIdAmountPathCallsCount,
            1
        )
    }
}

private extension XcmExtrinsicBuilderTests {
    private enum TestData {
        static let chainModel = ChainModel(
            rank: 0,
            disabled: false,
            chainId: "0",
            paraId: "0",
            name: "model",
            tokens: ChainRemoteTokens(type: .config, whitelist: nil, utilityId: nil, tokens: []),
            xcm: XcmChain(
                xcmVersion: .V1,
                destWeightIsPrimitive: true,
                availableAssets: [.init(
                    id: "0",
                    symbol: "0"
                )],
                availableDestinations: [.init(
                    chainId: "1",
                    bridgeParachainId: "2",
                    assets: [.init(
                        id: "0",
                        symbol: "0"
                    )]
                )]
            ),
            nodes: Set([ChainNodeModel(
                url: XcmConfig.shared.tokenLocationsSourceUrl,
                name: "node",
                apikey: nil
            )]),

            icon: nil,
            iosMinAppVersion: nil,
            properties: ChainProperties(addressPrefix: "0")
        )

        static let reserveTransferCall = ReserveTransferAssetsCall(
            destination: .V1(.init(
                parents: 0,
                interior: .init(items: [.onlyChild])
            )),
            beneficiary: .V1(.init(
                parents: 1,
                interior: .init(items: [.parachain(2)])
            )),
            assets: .V1([.init(
                assetId: .abstract(Data()),
                fun: .fungible(amount: BigUInt())
            )]),
            weightLimit: .unlimited,
            feeAssetItem: 3
        )

        static let xTokensTransferCall = XTokensTransferCall(
            currencyId: .xcm(id: "0"),
            amount: BigUInt(),
            dest: .V1(.init(
                parents: 0,
                interior: .init(items: [.onlyChild])
            )),
            destWeightLimit: .unlimited
        )

        static let xTokenMultiassetCall = XTokensTransferMultiassetCall(
            asset: .V1(.init(
                assetId: .abstract(Data()),
                fun: .fungible(amount: BigUInt())
            )),
            dest: .V1(.init(
                parents: 0,
                interior: .init(items: [.onlyChild])
            )),
            destWeightLimit: .unlimited,
            destWeightIsPrimitive: true,
            destWeight: BigUInt()
        )

        static let bridgeProxyCall = BridgeProxyBurnCall(
            networkId: .evm(BigUInt()),
            assetId: .init(wrappedValue: "0"),
            recipient: .root,
            amount: BigUInt()
        )
    }

    private func createRuntimeCall<T>(_ args: T) -> RuntimeCall<T> {
        RuntimeCall(moduleName: "", callName: "", args: args)
    }
}
