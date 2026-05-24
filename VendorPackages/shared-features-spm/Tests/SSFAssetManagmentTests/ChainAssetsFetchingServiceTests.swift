import MocksBasket
import SSFModels
import XCTest

@testable import SSFAssetManagment

final class ChainAssetsFetchingServiceTests: XCTestCase {
    func testFetchEmptyArray() async {
        // arrange
        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = []

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(filters: [], sorts: [], forceUpdate: false)

        // assert
        XCTAssertEqual(chainAssets.count, 0)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchOneAsset() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(filters: [], sorts: [], forceUpdate: false)

        // assert
        XCTAssertEqual(chainAssets.count, 1)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterChainId() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.chainId("Kusama")],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 1)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterChainIdEmptyArray() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.chainId("test")],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 0)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterHasStaking() async {
        // arrange
        let chain = TestData.chainWithStacking
        let asset = TestData.assetWithStacking

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.hasStaking(true)],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 1)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterHasCrowdloan() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.hasCrowdloans(true)],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 1)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterNoCrowdloan() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.hasCrowdloans(false)],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 0)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterAssetName() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.assetName("XOR")],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 1)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterAssetNameEmptyArray() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.assetName("test")],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 0)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterSearch() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.search("XOR")],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 1)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterSearchEmptyArray() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.search("test111")],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 0)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterEcosystem() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.ecosystem(.ethereum)],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 1)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterEcosystemEmptyArray() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.ecosystem(.kusama)],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 0)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterChainIds() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.chainIds(["Kusama"])],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 1)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterChainIdsEmptyArray() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.chainIds(["test"])],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 0)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterSupportNfts() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.supportNfts],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 1)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchFilterSupportNftsEmptyArray() async {
        // arrange
        let chain = TestData.chainWithStacking
        let asset = TestData.assetWithStacking

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = [chainAsset]

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [.supportNfts],
            sorts: [],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 0)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
    }

    func testFetchSortPrice() async {
        // arrange
        let chain = ChainModel(
            rank: 1,
            disabled: true,
            chainId: "Kusama",
            parentId: "2",
            paraId: "test",
            name: "test",
            tokens: ChainRemoteTokens(
                type: .config,
                whitelist: nil,
                utilityId: nil,
                tokens: [TestData.asset, TestData.assetWithStacking]
            ),
            xcm: nil,
            nodes: [],
            icon: nil,
            iosMinAppVersion: nil,
            properties: .init(addressPrefix: "1", rank: "2", paraId: "test", ethereumBased: true)
        )

        let extectedAssetArray = chain.tokens.tokens?.compactMap { ChainAsset(chain: chain, asset: $0) }

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = extectedAssetArray

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [],
            sorts: [.price(.descending)],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 2)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
        XCTAssertEqual(chainAssets, extectedAssetArray)
    }

    func testFetchSortAssetName() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        chain.tokens = ChainRemoteTokens(
            type: .config,
            whitelist: nil,
            utilityId: nil,
            tokens: [asset]
        )

        let chainWithStacking = TestData.chainWithStacking
        let assetWithStacking = TestData.assetWithStacking
        let chainAssetWithStacking = ChainAsset(chain: chainWithStacking, asset: assetWithStacking)
        chainWithStacking.tokens = ChainRemoteTokens(
            type: .config,
            whitelist: nil,
            utilityId: nil,
            tokens: [assetWithStacking]
        )

        let extectedAssetArray = [chainAsset, chainAssetWithStacking]

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = extectedAssetArray

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [],
            sorts: [.assetName(.ascending)],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 2)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
        XCTAssertEqual(chainAssets, extectedAssetArray)
    }

    func testFetchSortChainName() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        chain.tokens = ChainRemoteTokens(
            type: .config,
            whitelist: nil,
            utilityId: nil,
            tokens: [asset]
        )

        let chainWithStacking = TestData.chainWithStacking
        let assetWithStacking = TestData.assetWithStacking
        let chainAssetWithStacking = ChainAsset(chain: chainWithStacking, asset: assetWithStacking)
        chainWithStacking.tokens = ChainRemoteTokens(
            type: .config,
            whitelist: nil,
            utilityId: nil,
            tokens: [assetWithStacking]
        )

        let extectedAssetArray = [chainAsset, chainAssetWithStacking]

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = extectedAssetArray

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [],
            sorts: [.chainName(.ascending)],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 2)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
        XCTAssertEqual(chainAssets, extectedAssetArray)
    }

    func testFetchSortIsTest() async {
        // arrange
        let chain = TestData.chain
        let asset = TestData.asset
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        chain.tokens = ChainRemoteTokens(type: .config, whitelist: nil, utilityId: nil, tokens: [asset])

        let chainWithStacking = TestData.chainWithStacking
        let assetWithStacking = TestData.assetWithStacking
        let chainAssetWithStacking = ChainAsset(chain: chainWithStacking, asset: assetWithStacking)
        chainWithStacking.tokens = ChainRemoteTokens(
            type: .config,
            whitelist: nil,
            utilityId: nil,
            tokens: [assetWithStacking]
        )

        let extectedAssetArray = [chainAsset, chainAssetWithStacking]

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = extectedAssetArray

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [],
            sorts: [.isTest(.descending)],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 2)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
        XCTAssertEqual(chainAssets, extectedAssetArray)
    }

    func testFetchSortIsPolkadotOrKusama() async {
        // arrange
        let chain = TestData.chain
        chain.tokens = ChainRemoteTokens(
            type: .config,
            whitelist: nil,
            utilityId: nil,
            tokens: [TestData.asset, TestData.assetWithStacking]
        )

        let extectedAssetArray = chain.tokens.tokens?.map { ChainAsset(chain: chain, asset: $0) }

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = extectedAssetArray

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [],
            sorts: [.isPolkadotOrKusama(.ascending)],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 2)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
        XCTAssertEqual(chainAssets, extectedAssetArray)
    }

    func testFetchSortAssetId() async {
        // arrange
        let chain = ChainModel(
            rank: 3,
            disabled: true,
            chainId: "Kusama",
            parentId: "2",
            paraId: "test",
            name: "test",
            tokens: ChainRemoteTokens(
                type: .config,
                whitelist: nil,
                utilityId: nil,
                tokens: [TestData.asset, TestData.assetWithStacking]
            ),
            xcm: nil,
            nodes: [],
            icon: nil,
            iosMinAppVersion: nil,
            properties: .init(addressPrefix: "1", rank: "2", paraId: "test", ethereumBased: true)
        )

        let extectedAssetArray = chain.tokens.tokens?.compactMap { ChainAsset(chain: chain, asset: $0) }

        let chainAssetsFetcher = ChainAssetsFetchWorkerProtocolMock()
        chainAssetsFetcher.getChainAssetsModelsReturnValue = extectedAssetArray

        let service = ChainAssetsFetchingService(chainAssetsFetcher: chainAssetsFetcher)

        // act
        let chainAssets = await service.fetch(
            filters: [],
            sorts: [.assetId(.descending)],
            forceUpdate: false
        )

        // assert
        XCTAssertEqual(chainAssets.count, 2)
        XCTAssertTrue(chainAssetsFetcher.getChainAssetsModelsCalled)
        XCTAssert(chainAssetsFetcher.getChainAssetsModelsCallsCount == 1)
        XCTAssertEqual(chainAssets, extectedAssetArray)
    }
}

private extension ChainAssetsFetchingServiceTests {
    enum TestData {
        static let chain = ChainModel(
            rank: 1,
            disabled: true,
            chainId: "Kusama",
            paraId: "test",
            name: "test",
            tokens: ChainRemoteTokens(
                type: .config,
                whitelist: nil,
                utilityId: nil,
                tokens: [asset]
            ),
            xcm: nil,
            nodes: [],
            icon: nil,
            iosMinAppVersion: nil,
            properties: .init(addressPrefix: "test", ethereumBased: true, crowdloans: true)
        )

        static let asset = AssetModel(
            id: "2",
            name: "test",
            symbol: "XOR",
            isUtility: true,
            precision: 1,
            substrateType: .soraAsset,
            ethereumType: nil,
            tokenProperties: nil,
            price: nil,
            priceId: nil,
            coingeckoPriceId: nil,
            priceProvider: nil
        )
        
        static let chainWithStacking = ChainModel(
            rank: 2,
            disabled: true,
            chainId: "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
            paraId: "test",
            name: "test1",
            tokens: ChainRemoteTokens(
                type: .config,
                whitelist: nil,
                utilityId: nil,
                tokens: [assetWithStacking]
            ),
            xcm: nil,
            nodes: [],
            icon: nil,
            iosMinAppVersion: nil,
            properties: .init(addressPrefix: "1", crowdloans: false)
        )

        static let assetWithStacking = AssetModel(
            id: "3",
            name: "test",
            symbol: "XOR2",
            isUtility: true,
            precision: 1,
            substrateType: .soraAsset,
            ethereumType: nil,
            tokenProperties: TokenProperties(stacking: "relaychain"),
            price: nil,
            priceId: nil,
            coingeckoPriceId: nil,
            priceProvider: nil
        )
    }
}
