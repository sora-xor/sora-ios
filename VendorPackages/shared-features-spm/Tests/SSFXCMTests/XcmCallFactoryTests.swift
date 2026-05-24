import BigInt
import SSFModels
import SSFUtils
import XCTest

@testable import SSFXCM

final class XcmCallFactoryTests: XCTestCase {
    var factory: XcmCallFactoryProtocol?
    var fetcher: XcmAssetMultilocationFetchingMock?

    override func setUp() {
        super.setUp()

        let fetcher = XcmAssetMultilocationFetchingMock()
        fetcher.versionedMultilocationOriginAssetIdDestChainIdReturnValue = TestData.multilocation
        self.fetcher = fetcher

        factory = XcmCallFactory(assetMultilocationFetcher: fetcher)
    }

    override func tearDown() {
        super.tearDown()
        fetcher = nil
        factory = nil
    }

    func testReserveNativeToken() {
        // arrange
        let version: XcmCallFactoryVersion = .V1
        let fromChainModel: ChainModel = TestData.model
        let destChainModel: ChainModel = TestData.model
        let destAccountId: AccountId = Data()
        let amount = BigUInt()
        let weightLimit = BigUInt()
        let path: XcmCallPath = .parachainId
        let moduleName = "parachainInfo"
        let itemName = "parachainId"

        // act
        let runtimeCall = factory?.reserveNativeToken(
            version: version,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            destAccountId: destAccountId,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        // assert
        XCTAssertNotNil(runtimeCall)
        XCTAssertEqual(runtimeCall?.moduleName, moduleName)
        XCTAssertEqual(runtimeCall?.callName, itemName)
    }

    func testXTokensTransfer() {
        // arrange
        let version: XcmCallFactoryVersion = .V1
        let accountId: AccountId = Data()
        let currencyId: CurrencyId = .xcm(id: "1")
        let destChainModel: ChainModel = TestData.model
        let amount = BigUInt()
        let weightLimit = BigUInt()
        let path: XcmCallPath = .parachainId
        let moduleName = "parachainInfo"
        let itemName = "parachainId"

        // act
        let runtimeCall = factory?.xTokensTransfer(
            version: version,
            accountId: accountId,
            currencyId: currencyId,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        // assert
        XCTAssertNotNil(runtimeCall)
        XCTAssertEqual(runtimeCall?.moduleName, moduleName)
        XCTAssertEqual(runtimeCall?.callName, itemName)
    }

    func testXTokensTransferMultiasset() async throws {
        // arrange
        let version: XcmCallFactoryVersion = .V1
        let assetSymbol = "0"
        let accountId: AccountId = Data()
        let fromChainModel: ChainModel = TestData.model
        let destChainModel: ChainModel = TestData.model
        let amount = BigUInt()
        let weightLimit = BigUInt()
        let path: XcmCallPath = .parachainId
        let moduleName = "parachainInfo"
        let itemName = "parachainId"

        // act
        let runtimeCall = try await factory?.xTokensTransferMultiasset(
            version: version,
            assetSymbol: assetSymbol,
            accountId: accountId,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path,
            destWeightIsPrimitive: false
        )

        // assert
        XCTAssertNotNil(runtimeCall)
        XCTAssertEqual(runtimeCall?.moduleName, moduleName)
        XCTAssertEqual(runtimeCall?.callName, itemName)
    }

    func testXTokensTransferMultiassetWithError() async throws {
        // arrange
        let version: XcmCallFactoryVersion = .V1
        let assetSymbol = "0"
        let accountId: AccountId = Data()
        let fromChainModel: ChainModel = TestData.model
        let destChainModel: ChainModel = TestData.model
        let amount = BigUInt()
        let weightLimit = BigUInt()
        let path: XcmCallPath = .parachainId

        // act
        do {
            try await factory?.xTokensTransferMultiasset(
                version: version,
                assetSymbol: assetSymbol,
                accountId: accountId,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel,
                amount: amount,
                weightLimit: weightLimit,
                path: path,
                destWeightIsPrimitive: false
            )
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.noAvailableXcmAsset(symbol: assetSymbol).localizedDescription
            )
        }
    }

    func testPolkadotXcmLimitedReserveTransferAssets() async throws {
        // arrange
        let version: XcmCallFactoryVersion = .V1
        let assetSymbol = "0"
        let accountId: AccountId = Data()
        let fromChainModel: ChainModel = TestData.model
        let destChainModel: ChainModel = TestData.model
        let amount = BigUInt()
        let weightLimit = BigUInt()
        let path: XcmCallPath = .parachainId
        let moduleName = "parachainInfo"
        let itemName = "parachainId"

        // act
        let runtimeCall = try await factory?.polkadotXcmLimitedReserveTransferAssets(
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
        XCTAssertNotNil(runtimeCall)
        XCTAssertEqual(runtimeCall?.moduleName, moduleName)
        XCTAssertEqual(runtimeCall?.callName, itemName)
    }

    func testPolkadotXcmLimitedReserveTransferAssetsWithError() async throws {
        // arrange
        let version: XcmCallFactoryVersion = .V1
        let assetSymbol = "0"
        let accountId: AccountId = Data()
        let fromChainModel: ChainModel = TestData.model
        let destChainModel: ChainModel = TestData.model
        let amount = BigUInt()
        let weightLimit = BigUInt()
        let path: XcmCallPath = .parachainId

        // act
        do {
            try await factory?.polkadotXcmLimitedReserveTransferAssets(
                fromChainModel: fromChainModel,
                version: version,
                assetSymbol: assetSymbol,
                accountId: accountId,
                destChainModel: destChainModel,
                amount: amount,
                weightLimit: weightLimit,
                path: path
            )
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.noAvailableXcmAsset(symbol: assetSymbol).localizedDescription
            )
        }
    }

    func testBridgeProxyBurn() {
        // arrange
        let fromChainModel: ChainModel = TestData.model
        let currencyId = "0"
        let destChainModel: ChainModel = TestData.model
        let accountId: AccountId = Data()
        let amount = BigUInt()
        let path: XcmCallPath = .parachainId
        let moduleName = "parachainInfo"
        let itemName = "parachainId"

        // act
        let runtimeCall = factory?.bridgeProxyBurn(
            fromChainModel: fromChainModel,
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        )

        // assert
        XCTAssertNotNil(runtimeCall)
        XCTAssertEqual(runtimeCall?.moduleName, moduleName)
        XCTAssertEqual(runtimeCall?.callName, itemName)
    }
}

extension XcmCallFactoryTests {
    enum TestData {
        static let multilocation = AssetMultilocation(
            id: "0",
            symbol: "0",
            interiors: [.onlyChild]
        )

        static let chain = XcmChain(
            xcmVersion: .V1,
            destWeightIsPrimitive: true,
            availableAssets: [.init(id: "0", symbol: "0")],
            availableDestinations: [.init(
                chainId: "1",
                bridgeParachainId: "2",
                assets: [.init(
                    id: "0",
                    symbol: "0"
                )]
            )]
        )

        static let node = ChainNodeModel(
            url: XcmConfig.shared.tokenLocationsSourceUrl,
            name: "node",
            apikey: nil
        )

        static let model = ChainModel(
            rank: 0,
            disabled: false,
            chainId: "0",
            paraId: "0",
            name: "model",
            tokens: ChainRemoteTokens(type: .config, whitelist: nil, utilityId: nil, tokens: []),
            xcm: chain,
            nodes: Set([node]),
            icon: nil,
            iosMinAppVersion: nil,
            properties: ChainProperties(addressPrefix: "0")
        )
    }
}
