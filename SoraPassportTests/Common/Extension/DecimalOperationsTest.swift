import XCTest
import SoraFoundation
@testable import SoraPassport

class DecimalOperations: XCTestCase {

    func testScaleReductionDropsExtraDigitsWithoutChangingTheMagnitude() {
        XCTAssertEqual(Decimal(string: "1.299")!.reduceScale(to: 1), Decimal(string: "1.2"))
        XCTAssertEqual(Decimal(string: "129.99")!.reduceScale(to: 0), 129)
        XCTAssertEqual(Decimal(1234).reduceScale(to: -2), 1200)
    }

    func testScaleReductionPreservesTheSmallestXorUnitAtItsPrecision() {
        let unit = Decimal(string: "0.000000000000000001")!
        XCTAssertEqual(unit.reduceScale(to: 18), unit)
        XCTAssertEqual(unit.reduceScale(to: 17), 0)
        XCTAssertEqual(Decimal.zero.reduceScale(to: 18), 0)
    }

    func testRoundingModesHandleSignedTies() {
        XCTAssertEqual(Decimal(string: "1.25")!.rounded(with: 1, mode: .down), Decimal(string: "1.2"))
        XCTAssertEqual(Decimal(string: "-1.25")!.rounded(with: 1, mode: .down), Decimal(string: "-1.3"))
        XCTAssertEqual(Decimal(string: "1.25")!.rounded(with: 1, mode: .bankers), Decimal(string: "1.2"))
        XCTAssertEqual(Decimal(string: "1.35")!.rounded(with: 1, mode: .bankers), Decimal(string: "1.4"))
    }

    func testWholeNumberRejectsFractionsAndNotANumber() {
        for value in [Decimal.zero, 1, -1, Decimal(string: "9007199254740993")!] {
            XCTAssertTrue(value.isWholeNumber)
        }
        for value in [Decimal.nan, Decimal(string: "0.000000000000000001")!, Decimal(string: "-1.1")!] {
            XCTAssertFalse(value.isWholeNumber)
        }
    }

    func testAbbreviatedMarketCapsUseOneFractionDigit() {
        let previous = LocalizationManager.shared.selectedLocalization
        defer { LocalizationManager.shared.selectedLocalization = previous }
        LocalizationManager.shared.selectedLocalization = "en"
        XCTAssertEqual(Decimal(1_234).formatNumber(), "1.2K")
        XCTAssertEqual(Decimal(1_299_999).formatNumber(), "1.2M")
        XCTAssertEqual(Decimal(1_299_999_999).formatNumber(), "1.2B")
        XCTAssertEqual(Decimal(-1_234).formatNumber(), "-1.2K")
        XCTAssertEqual(Decimal.zero.formatNumber(), "0")
    }

    func testRoundedStringFromDecimal() {
        let decimalValue: Decimal = 1212.23
        let rounded = decimalValue.rounded(mode: .down)
        XCTAssertEqual("1212", (rounded.stringWithPointSeparator))
    }

}
