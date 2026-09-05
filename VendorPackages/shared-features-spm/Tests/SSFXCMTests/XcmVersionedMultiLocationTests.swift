import BigInt
import XCTest

@testable import SSFXCM

final class XcmVersionedMultiLocationTests: XCTestCase {
    func testEncode() throws {
        // arrange
        let multilocation = XcmVersionedMultiLocation.V1(.init(
            parents: 0,
            interior: .init(items: [.onlyChild])
        ))

        // act
        let encodedData = try JSONEncoder().encode(multilocation)

        // assert
        XCTAssertEqual(encodedData.count, TestData.multilocationData?.count)
    }
}

extension XcmVersionedMultiLocationTests {
    enum TestData {
        static let multilocationData = """
        ["V1",{"interior":["X1",["OnlyChild",null]],"parents":"0"}]
        """.data(using: .utf8)
    }
}
