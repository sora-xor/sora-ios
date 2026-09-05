import XCTest

@testable import SSFXCM

final class XcmCallPathTests: XCTestCase {
    func testPathParameters() {
        // arrange
        let moduleName = "parachainInfo"
        let itemName = "parachainId"
        let path = (moduleName: moduleName, itemName: itemName)

        // act
        let xcmPath: XcmCallPath = .parachainId

        // assert
        XCTAssertEqual(xcmPath.path.moduleName, moduleName)
        XCTAssertEqual(xcmPath.path.itemName, itemName)

        XCTAssertEqual(xcmPath.moduleName, moduleName)
        XCTAssertEqual(xcmPath.itemName, itemName)
    }

    func testUsedRuntimePathsParameter() {
        // act
        let usedRuntimePaths = XcmCallPath.usedRuntimePaths

        // assert
        XCTAssertEqual(usedRuntimePaths.count, 6)
    }
}
