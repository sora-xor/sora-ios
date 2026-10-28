import XCTest

@testable import SSFXCM

final class XcmJunctionTests: XCTestCase {
    func testIsParachain() {
        // arrange
        let junction = XcmJunction.parachain(0)

        // act
        let isParachain = junction.isParachain()

        // assert
        XCTAssertTrue(isParachain)
    }

    func testEncode() throws {
        // arrange
        let junction = XcmJunction.onlyChild

        // act
        let encodedData = try JSONEncoder().encode(junction)

        // assert
        XCTAssertEqual(encodedData, TestData.xcmJunctionData)
    }

    func testInitFromDecoder() throws {
        // act
        let junction = try JSONDecoder().decode(
            XcmJunction.self,
            from: TestData.decodedData ?? Data()
        )

        // assert
        XCTAssertTrue(junction.isParachain())
    }

    func testEquatable() {
        // arrange
        let junction1 = XcmJunction.generalKey(Data())
        let junction2 = XcmJunction.generalKey(Data())

        // assert
        XCTAssertEqual(junction1, junction2)
    }
}

extension XcmJunctionTests {
    enum TestData {
        static let xcmJunctionData = """
        ["OnlyChild",null]
        """.data(using: .utf8)

        static let decodedData = """
        {"parachain": 42}
        """.data(using: .utf8)
    }
}
