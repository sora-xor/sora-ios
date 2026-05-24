import XCTest

@testable import SSFQRService

final class QRMatcherTests: XCTestCase {
    func testQRUriMatcherBokoloCash() async throws {
        // arrange
        let address = ""
        let bokoloQRCodeString =
            "https://bokolodemo.page.link/data?qr=00020101021129180014ivan_ivan@auki5204599953030905802LA5909Ivan%20Ivan6010Phnom%20Penh6304DCAF"
        let matcher = QRUriMatcherImpl(scheme: "https")

        // act
        let qrType = matcher.match(code: bokoloQRCodeString)

        // assert
        XCTAssertNotNil(qrType)
        XCTAssertNil(qrType?.address)
        XCTAssertNil(qrType?.qrInfo)
        XCTAssertEqual(qrType?.uri, bokoloQRCodeString)
    }

    func testQRUriMatcherBokoloCashWithAmount() async throws {
        // arrange
        let address = ""
        let bokoloQRCodeString =
            "https://bokolodemo.page.link/data?qr=00020101021229180014ivan_ivan@auki52045999530309054031.55802LA5909Ivan%20Ivan6010Phnom%20Penh6304A2CA"
        let matcher = QRUriMatcherImpl(scheme: "https")

        // act
        let qrType = matcher.match(code: bokoloQRCodeString)

        // assert
        XCTAssertNotNil(qrType)
        XCTAssertNil(qrType?.address)
        XCTAssertNil(qrType?.qrInfo)
        XCTAssertEqual(qrType?.uri, bokoloQRCodeString)
    }

    func testQRUriMatcherEmpty() async throws {
        // arrange
        let matcher = QRUriMatcherImpl(scheme: "https")

        // act
        let qrType = matcher.match(code: "")

        // assert
        XCTAssertNil(qrType)
    }
}
