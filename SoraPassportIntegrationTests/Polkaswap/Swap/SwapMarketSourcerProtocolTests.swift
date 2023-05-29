import XCTest
@testable import SoraPassport

let valId = WalletAssetId.val.rawValue
let pswapId = WalletAssetId.pswap.rawValue
let daiId = "0x0200060000000000000000000000000000000000000000000000000000000000"
let ethId = "0x0200070000000000000000000000000000000000000000000000000000000000"
let xstusdId = WalletAssetId.xstusd.rawValue

class SwapMarketSourcerProtocolTests: XCTestCase {

    var marketSourcer = SwapMarketSourcer(fromAssetId: valId, toAssetId: pswapId)

    override func setUp() {
        marketSourcer = SwapMarketSourcer(fromAssetId: valId, toAssetId: pswapId)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSetAndGetMarketSources() {
        // given
        let marketSources = [LiquiditySourceType.smart, LiquiditySourceType.tbc]

        // when
        marketSourcer.setMarketSources(marketSources)

        // then
        XCTAssertEqual(marketSourcer.getMarketSources(), marketSources)
    }

    func testAddMarketSource() {
        // given
        let marketSources = [LiquiditySourceType.smart, LiquiditySourceType.tbc]

        // when
        marketSourcer.setMarketSources(marketSources)
        marketSourcer.add(LiquiditySourceType.xyk)

        // then
        XCTAssertEqual(marketSourcer.getMarketSources(), [.smart, .tbc, .xyk])
    }

    func testAddSmartIfNotEmpty() {
        // given
        let marketSources = [LiquiditySourceType.tbc]
        marketSourcer.setMarketSources(marketSources)

        // when
        marketSourcer.addSmartIfNotEmpty()

        // then
        XCTAssertEqual(marketSourcer.getMarketSources(), [LiquiditySourceType.tbc, LiquiditySourceType.smart])
    }

    func testNotAddSmartIfEmpty() {
        // given

        // when
        marketSourcer.addSmartIfNotEmpty()

        // then
        XCTAssertEqual(marketSourcer.getMarketSources().count, 0)
        XCTAssertTrue(marketSourcer.isEmpty())
    }

    func testSetMarketsFromServerSources() {
        // given
        let serverMarketSources: [String] = [LiquiditySourceType.xyk.rawValue, LiquiditySourceType.tbc.rawValue]

        // when
        marketSourcer.setMarketSources(from: serverMarketSources)

        // then
        XCTAssertEqual(marketSourcer.getMarketSources(), [LiquiditySourceType.xyk, LiquiditySourceType.tbc])
    }

    func testAddsSmartIfEmptySourcesFromXSTUSDToSpecialAsset() {
        // given
        marketSourcer = SwapMarketSourcer(fromAssetId: xstusdId, toAssetId: valId)
        XCTAssertTrue(marketSourcer.isEmpty())

        // when
        marketSourcer.didLoad([])

        // then
        XCTAssertEqual(marketSourcer.getMarketSources(), [LiquiditySourceType.smart])
    }

    func testAddsSmartIfEmptySourcesFromSpecialAssetToXSTUSD() {
        // given
        marketSourcer = SwapMarketSourcer(fromAssetId: valId, toAssetId: xstusdId)
        XCTAssertTrue(marketSourcer.isEmpty())

        // when
        marketSourcer.didLoad([])

        // then
        XCTAssertEqual(marketSourcer.getMarketSources(), [LiquiditySourceType.smart])
    }

    func testNotAddSmartIfNotSwapXSTUSD() {
        func testAddsSmartIfEmptySourcesFromSpecialAssetToXSTUSD() {
            // given
            marketSourcer = SwapMarketSourcer(fromAssetId: valId, toAssetId: pswapId)
            XCTAssertTrue(marketSourcer.isEmpty())

            // when
            marketSourcer.didLoad([])

            // then
            XCTAssertEqual(marketSourcer.getMarketSources(), [])
        }
    }

    func testAddSmartIfNotEmptyWhenDidLoad() {
        //given

        // when
        marketSourcer.didLoad([LiquiditySourceType.xyk.rawValue])

        // then
        XCTAssertEqual(marketSourcer.getMarketSources(), [LiquiditySourceType.xyk, LiquiditySourceType.smart])
    }

    func testGetMarketSourceAtIndex() {
        // given

        // when
        marketSourcer.didLoad([LiquiditySourceType.xyk.rawValue, LiquiditySourceType.tbc.rawValue])

        // then
        XCTAssertEqual(marketSourcer.getMarketSources(), [LiquiditySourceType.xyk, LiquiditySourceType.tbc, LiquiditySourceType.smart])
        XCTAssertEqual(marketSourcer.getMarketSource(at: 0), LiquiditySourceType.xyk)
        XCTAssertEqual(marketSourcer.getMarketSource(at: 1), LiquiditySourceType.tbc)
        XCTAssertEqual(marketSourcer.getMarketSource(at: 2), LiquiditySourceType.smart)
    }

    func testGetNonsmartMarketSources() {
        //given
        marketSourcer.setMarketSources([.xyk, .tbc, .smart])

        //when
        let marketSources = marketSourcer.getServerMarketSources()

        // then
        XCTAssertEqual(marketSources, [LiquiditySourceType.xyk.rawValue, LiquiditySourceType.tbc.rawValue])
    }

    func testGetIndexOfAsset() {
        //given
        marketSourcer.setMarketSources([.xyk, .tbc, .smart])

        //when
        let indexXyk = marketSourcer.index(of: .xyk)
        let indexTbc = marketSourcer.index(of: .tbc)
        let indexSmart = marketSourcer.index(of: .smart)

        //then
        XCTAssertEqual(indexXyk, 0)
        XCTAssertEqual(indexTbc, 1)
        XCTAssertEqual(indexSmart, 2)
    }

    func testContainsMarketSource() {
        // given
        marketSourcer.setMarketSources([.xyk, .smart])

        // when
        let containsXyk = marketSourcer.contains(.xyk)
        let containsTbc = marketSourcer.contains(.tbc)
        let containsSmart = marketSourcer.contains(.smart)

        // then
        XCTAssertTrue(containsXyk)
        XCTAssertFalse(containsTbc)
        XCTAssertTrue(containsSmart)
    }
}
