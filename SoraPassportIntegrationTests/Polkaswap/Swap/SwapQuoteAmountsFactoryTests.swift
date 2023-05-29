import XCTest
@testable import SoraPassport

class SwapQuoteAmountsFactoryTests: XCTestCase {

    let mockQuoteOutputParams = PolkaswapMainInteractorQuoteParams(fromAssetId: mockVal.assetId, toAssetId: mockPswap.assetId, amount: "", swapVariant: .desiredOutput, liquiditySources: [], filterMode: .allowSelected)

    func testCreateAmounts() {
        // given
        let params = PolkaswapMainInteractorQuoteParams(fromAssetId: mockVal.assetId, toAssetId: mockPswap.assetId, amount: "1000000000000000000", swapVariant: .desiredInput, liquiditySources: [], filterMode: .allowSelected)
        let quote: SwapValues = SwapValues(amount: "90872510487562233976", fee: "1529436522394950", rewards: [], route: [])
        let factory = SwapQuoteAmountsFactory()

        // when
        let amounts = factory.createAmounts(fromAsset: mockVal, toAsset: mockPswap, params: params, quote: quote)

        // then
        XCTAssertNotNil(amounts)
        XCTAssertEqual(amounts!.toAmount, 90.872510487562233976, accuracy: 0.00000001)
        XCTAssertEqual(amounts!.fromAmount, 1.0, accuracy: 0.00000001)
        XCTAssertEqual(amounts!.lpAmount, 0.001529436522394950, accuracy: 0.00000001)
    }
}
