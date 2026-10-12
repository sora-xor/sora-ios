import BigInt
import SSFModels
import XCTest

@testable import SSFXCM

final class XcmAccountsTests: XCTestCase {
    func testAccountId32ValueInit() {
        // arrange
        let network: XcmJunctionNetworkId = .kusama
        let accountId: AccountId = Data()

        // act
        let accountValue = AccountId32Value(
            network: network,
            accountId: accountId
        )

        // assert
        XCTAssertEqual(accountValue.network, network)
        XCTAssertEqual(accountValue.accountId, accountId)
    }

    func testAccountId20ValueInit() {
        // arrange
        let network: XcmJunctionNetworkId = .kusama
        let key: AccountId = Data()

        // act
        let accountValue = AccountId20Value(
            network: network,
            key: key
        )

        // assert
        XCTAssertEqual(accountValue.network, network)
        XCTAssertEqual(accountValue.key, key)
    }

    func testAccountIndexValueInit() {
        // arrange
        let network: XcmJunctionNetworkId = .kusama
        let index: UInt64 = 0

        // act
        let accountValue = AccountIndexValue(
            network: network,
            index: index
        )

        // assert
        XCTAssertEqual(accountValue.network, network)
        XCTAssertEqual(accountValue.index, index)
    }
}
