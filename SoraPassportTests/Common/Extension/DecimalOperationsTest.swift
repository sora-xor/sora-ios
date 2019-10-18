import XCTest
@testable import SoraPassport

class DecimalOperations: XCTestCase {

    func testRoundedStringFromDecimal() {
        let decimalValue: Decimal = 1212.23
        let rounded = decimalValue.rounded(mode: .down)
        XCTAssertEqual("1212", (rounded.stringWithPointSeparator))
    }

}
