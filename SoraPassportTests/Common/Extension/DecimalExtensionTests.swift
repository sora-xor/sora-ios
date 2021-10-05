import Foundation
import XCTest
@testable import SoraPassport

class DecimalExtensionTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testToStringConvertion() {
        XCTAssertEqual(Decimal(0).stringWithPointSeparator, "0")
        XCTAssertEqual(Decimal(sign: .plus, exponent: -3, significand: Decimal(333)).stringWithPointSeparator, "0.333")
        XCTAssertEqual(Decimal(sign: .minus, exponent: -2, significand: Decimal(23)).stringWithPointSeparator, "-0.23")
        XCTAssertEqual(Decimal(111).stringWithPointSeparator, "111")
        XCTAssertEqual(Decimal(1111).stringWithPointSeparator, "1111")
        XCTAssertEqual(Decimal(11111).stringWithPointSeparator, "11111")
        XCTAssertEqual(Decimal(sign: .plus, exponent: -1, significand: Decimal(111112)).stringWithPointSeparator, "11111.2")
        XCTAssertEqual(Decimal(sign: .minus, exponent: -5, significand: Decimal(1111123456)).stringWithPointSeparator, "-11111.23456")
    }
}
