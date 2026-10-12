import BigInt
import XCTest

@testable import SSFXCM

final class XcmVersionedMultiAssetTests: XCTestCase {
    func testEncode() throws {
        // arrange
        let asset = XcmVersionedMultiAsset.V1(.init(
            assetId: .abstract(Data()),
            fun: .fungible(amount: BigUInt())
        ))

        // act
        let encodedData = try JSONEncoder().encode(asset)

        // assert
        XCTAssertEqual(encodedData.count, TestData.assetData?.count)
    }
}

extension XcmVersionedMultiAssetTests {
    enum TestData {
        static let assetData = """
        ["V1",{"fun":["Fungible","0"],"id":["Abstract",[]]}]
        """.data(using: .utf8)
    }
}
