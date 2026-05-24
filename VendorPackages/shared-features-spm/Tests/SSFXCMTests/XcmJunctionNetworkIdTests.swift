import SSFModels
import XCTest

@testable import SSFXCM

final class XcmJunctionNetworkIdTests: XCTestCase {
    func testEncode() throws {
        // arrange
        let networkId = XcmJunctionNetworkId.polkadot

        // act
        let encodedData = try JSONEncoder().encode(networkId)

        // assert
        XCTAssertEqual(encodedData, TestData.networkIdData)
    }

    func testFromEcosystem() {
        // arrange
        let ecosystem: ChainEcosystem = .ethereum

        // act
        let id = XcmJunctionNetworkId.from(ecosystem: ecosystem)

        // assert
        XCTAssertEqual(id, .ethereum)
    }
}

extension XcmJunctionNetworkIdTests {
    enum TestData {
        static let networkIdData = """
        ["Polkadot",null]
        """.data(using: .utf8)
    }
}
