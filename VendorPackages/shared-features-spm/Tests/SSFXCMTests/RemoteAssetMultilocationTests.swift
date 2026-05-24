import XCTest

@testable import SSFXCM

final class RemoteAssetMultilocationTests: XCTestCase {
    func testRemoteAssetMultilocationInit() {
        // arrange
        let name = "test"
        let chainId = "id"
        let assets: [AssetMultilocation] = [AssetMultilocation(
            id: "assetId",
            symbol: "assetSymbol",
            interiors: [.onlyChild]
        )]

        // act
        let remote = RemoteAssetMultilocation(
            name: name,
            chainId: chainId,
            assets: assets
        )
        // assert
        XCTAssertEqual(remote.name, name)
        XCTAssertEqual(remote.chainId, chainId)
        XCTAssertEqual(remote.assets.count, 1)
    }

    func testAssetMultilocationInit() {
        // arrange
        let id = "assetId"
        let symbol = "assetSymbol"
        let interiors: [XcmJunction] = [.onlyChild]

        // act
        let multiplication = AssetMultilocation(
            id: id,
            symbol: symbol,
            interiors: interiors
        )
        // assert
        XCTAssertEqual(multiplication.id, id)
        XCTAssertEqual(multiplication.symbol, symbol)
        XCTAssertEqual(multiplication.interiors.count, 1)
    }
}
