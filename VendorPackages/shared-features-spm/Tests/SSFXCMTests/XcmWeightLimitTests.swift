import BigInt
import XCTest

@testable import SSFXCM

final class XcmWeightLimitTests: XCTestCase {
    func testEncode() throws {
        // arrange
        let weight = XcmWeightLimit.unlimited

        // act
        let encodedData = try JSONEncoder().encode(weight)

        // assert
        XCTAssertEqual(encodedData, TestData.weightData)
    }
}

extension XcmWeightLimitTests {
    enum TestData {
        static let weightData = """
        ["Unlimited"]
        """.data(using: .utf8)
    }
}
