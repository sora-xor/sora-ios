import XCTest

@testable import SSFXCM

final class XcmConfigTests: XCTestCase {
    var config: XcmConfigProtocol?

    override func setUp() {
        super.setUp()
        config = XcmConfig.shared
    }

    override func tearDown() {
        super.tearDown()
        config = nil
    }

    func testChainsSourceUrl() {
        // arrange
        let expectedUrlString = TestData.baseUrlString + TestData.rococoBranchString + TestData
            .chainUrlString

        // act
        let url = config?.chainsSourceUrl

        // assert
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedUrlString)
    }

    func testChainTypesSourceUrl() {
        // arrange
        let expectedUrlString = TestData.baseUrlString + TestData.rococoBranchString + TestData
            .typeUrlString

        // act
        let url = config?.chainTypesSourceUrl

        // assert
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedUrlString)
    }

    func testDestinationFeeSourceUrl() {
        // arrange
        let expectedUrlString = TestData.baseUrlString + TestData.rococoBranchString + TestData
            .destinationUrlString

        // act
        let url = config?.destinationFeeSourceUrl

        // assert
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedUrlString)
    }

    func testTokenLocationsSourceUrlokenLocationsSourceUrl() {
        // arrange
        let expectedUrlString = TestData.baseUrlString + TestData.masterBranchString + TestData
            .tokenUrlString

        // act
        let url = config?.tokenLocationsSourceUrl

        // assert
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedUrlString)
    }
}

private extension XcmConfigTests {
    private enum TestData {
        static let baseUrlString =
            "https://raw.githubusercontent.com/soramitsu/shared-features-utils/"
        static let rococoBranchString = "feature/rococo/"
        static let masterBranchString = "master/"
        static let chainUrlString = "chains/v4/chains_dev.json"
        static let typeUrlString = "chains/all_chains_types.json"
        static let destinationUrlString = "xcm/v2/xcm_fees.json"
        static let tokenUrlString = "xcm/v2/xcm_token_locations.json"
    }
}
