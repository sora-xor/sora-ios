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

final class AmountDecodingTests: XCTestCase {
    func testInitializersRejectPartialNumbersAndMalformedExponents() {
        for raw in invalidAmounts {
            XCTAssertNil(Amount(string: raw), "Amount accepted \(raw.debugDescription)")
            XCTAssertNil(AmountDecimal(string: raw), "AmountDecimal accepted \(raw.debugDescription)")
        }
    }

    func testDecodersRejectMalformedStringAmounts() throws {
        for raw in invalidAmounts {
            let data = try JSONEncoder().encode(raw)
            XCTAssertThrowsError(try JSONDecoder().decode(Amount.self, from: data))
            XCTAssertThrowsError(try JSONDecoder().decode(AmountDecimal.self, from: data))
        }
    }

    func testDecimalAndExponentFormsRemainCompatible() throws {
        let cases: [(String, Decimal)] = [
            ("0", 0), ("-0", 0), ("+1", 1), ("001.25", 1.25),
            (".5", 0.5), ("1.", 1), ("-1.25", -1.25),
            ("1e2", 100), ("1E+2", 100), ("1.25e-2", 0.0125)
        ]
        for (raw, expected) in cases {
            let data = try JSONEncoder().encode(raw)
            XCTAssertEqual(Amount(string: raw)?.decimalValue, expected)
            XCTAssertEqual(AmountDecimal(string: raw)?.decimalValue, expected)
            XCTAssertEqual(try JSONDecoder().decode(Amount.self, from: data).decimalValue, expected)
            XCTAssertEqual(try JSONDecoder().decode(AmountDecimal.self, from: data).decimalValue, expected)
        }
    }

    func testSmallestXorUnitAndLargeIntegerRoundTripWithoutDoubleConversion() throws {
        for raw in ["0.000000000000000001", "9007199254740993", "12345678901234567890.123456789012345678"] {
            let amount = try XCTUnwrap(Amount(string: raw))
            let legacyAmount = try XCTUnwrap(AmountDecimal(string: raw))
            XCTAssertEqual(amount.stringValue, raw)
            XCTAssertEqual(legacyAmount.stringValue, raw)
            XCTAssertEqual(try JSONDecoder().decode(Amount.self, from: JSONEncoder().encode(amount)), amount)
            XCTAssertEqual(try JSONDecoder().decode(AmountDecimal.self, from: JSONEncoder().encode(legacyAmount)), legacyAmount)
        }
    }

    func testDecodersRequireStringAmounts() {
        for raw in ["1.25", "true", "null", "{}", "[]"] {
            let data = Data(raw.utf8)
            XCTAssertThrowsError(try JSONDecoder().decode(Amount.self, from: data))
            XCTAssertThrowsError(try JSONDecoder().decode(AmountDecimal.self, from: data))
        }
    }

    private var invalidAmounts: [String] {
        ["", " ", " 1", "1 ", "1\n", "1,25", "1.25XOR", "1.2.3", "1e", "1e+", "1e-",
         "NaN", "Infinity", "--1", ".", "١", "１", "1e999", "1e-999"]
    }
}
