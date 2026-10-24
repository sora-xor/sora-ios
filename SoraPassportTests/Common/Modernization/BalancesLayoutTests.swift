import BigInt
import XCTest
@testable import SoraPassport

/// SORA mainnet moved from `misc_frozen`/`fee_frozen` to `frozen`/`flags`.
/// Decoding only the old layout left every balance unreadable.
final class BalancesLayoutTests: XCTestCase {
    func testAccountDataDecodesTheOldLayout() throws {
        let data = try decode(#"{"free":"100","reserved":"5","miscFrozen":"10","feeFrozen":"20"}"#)

        XCTAssertEqual(data.locked, 20)
        XCTAssertEqual(data.available, 80)
        XCTAssertEqual(data.total, 105)
    }

    func testAccountDataDecodesTheCurrentLayout() throws {
        let data = try decode(#"{"free":"100","reserved":"5","frozen":"30","flags":"170141183460469231731687303715884105728"}"#)

        // `frozen` covers free plus reserved, so reserved absorbs 5 of it.
        XCTAssertEqual(data.locked, 25)
        XCTAssertEqual(data.available, 75)
        XCTAssertEqual(data.total, 105)
    }

    func testFrozenAboveFreeNeverUnderflows() throws {
        let data = try decode(#"{"free":"10","reserved":"0","frozen":"50","flags":"0"}"#)

        XCTAssertEqual(data.locked, 10)
        XCTAssertEqual(data.available, 0)
    }

    private func decode(_ json: String) throws -> AccountData {
        try JSONDecoder().decode(AccountData.self, from: Data(json.utf8))
    }
}
