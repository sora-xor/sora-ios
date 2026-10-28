// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import XCTest
@testable import SoraPassport

final class AssetMetadataCodingTests: XCTestCase {
    private func decode(_ fields: String) throws -> AssetInfo {
        try JSONDecoder().decode(AssetInfo.self, from: Data("{\"asset_id\":\"custom\",\"symbol\":\"TOKEN\",\"name\":\"Token\",\"precision\":\"18\"\(fields)}".utf8))
    }
    func testVisibleAssetMetadataDecodesWithoutTreatingVisibilityAsAPrice() throws {
        let value = try decode(",\"visible\":true")
        XCTAssertTrue(value.visible); XCTAssertNil(value.fiatPrice)
        XCTAssertEqual(value.name, "Token"); XCTAssertEqual(value.precision, 18)
    }
    func testHiddenAssetMetadataDecodesWithoutTreatingVisibilityAsAPrice() throws {
        let value = try decode(",\"visible\":false")
        XCTAssertFalse(value.visible); XCTAssertNil(value.fiatPrice)
    }
    func testAbsentOptionalMetadataKeepsAnUnpricedHiddenAsset() throws {
        let value = try decode("")
        XCTAssertFalse(value.visible); XCTAssertNil(value.fiatPrice); XCTAssertNil(value.icon)
    }
    func testAssetMetadataRoundTripPreservesVisibilityAndIdentity() throws {
        for visible in [false, true] {
            let original = AssetInfo(id: "custom", symbol: "TOKEN", chainId: "", precision: 6, icon: "token.svg", displayName: "Token", visible: visible)
            let restored = try JSONDecoder().decode(AssetInfo.self, from: JSONEncoder().encode(original))
            XCTAssertEqual(restored.identifier, original.identifier); XCTAssertEqual(restored.visible, visible)
            XCTAssertEqual(restored.symbol, original.symbol); XCTAssertEqual(restored.name, original.name)
            XCTAssertEqual(restored.precision, 6); XCTAssertEqual(restored.icon, "token.svg")
        }
    }
    func testRemoteMetadataCannotRenameTheNativeAsset() throws {
        let original = AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "Fake", chainId: "", precision: 18, icon: nil, displayName: "Spoof", visible: true)
        let restored = try JSONDecoder().decode(AssetInfo.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(restored.symbol, "XOR"); XCTAssertEqual(restored.name, "XOR"); XCTAssertTrue(restored.isFeeAsset)
    }
    func testInvalidVisibilityAndPrecisionAreRejected() {
        XCTAssertThrowsError(try decode(",\"visible\":\"true\""))
        let data = Data("{\"asset_id\":\"custom\",\"symbol\":\"TOKEN\",\"name\":\"Token\",\"precision\":\"-1\"}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(AssetInfo.self, from: data))
    }
}
