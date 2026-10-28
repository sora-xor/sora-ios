import Foundation
import RobinHood
import XCTest
@testable import SoraPassport

final class FoundationValidationBoundaryTests: XCTestCase {
    func testEmptyPredicatesDistinguishEmptyTextFromWhitespace() {
        for value in ["name", " ", "\n"] {
            XCTAssertTrue(NSPredicate.notEmpty.evaluate(with: value)); XCTAssertFalse(NSPredicate.empty.evaluate(with: value))
        }
        XCTAssertFalse(NSPredicate.notEmpty.evaluate(with: "")); XCTAssertTrue(NSPredicate.empty.evaluate(with: ""))
    }
    func testDerivationPathsPreserveHardSoftAndPasswordRules() {
        let cases: [(String, Bool, Bool, Bool, Bool)] = [
            ("", true, true, true, true), ("//hard", true, true, true, true),
            ("/soft", true, true, false, false), ("//hard/soft", true, true, false, false),
            ("//hard///password", true, false, false, true), ("///password", true, false, false, true),
            ("//hard//second", true, true, true, true), ("/", false, false, false, false),
            ("//", false, false, false, false), ("hard", false, false, false, false),
            ("////password", false, false, false, false), ("//hard/", false, false, false, false)
        ]
        for (value, any, noPassword, hard, hardPassword) in cases {
            XCTAssertEqual(NSPredicate.deriviationPathHardSoftPassword.evaluate(with: value), any, value)
            XCTAssertEqual(NSPredicate.deriviationPathHardSoft.evaluate(with: value), noPassword, value)
            XCTAssertEqual(NSPredicate.deriviationPathHard.evaluate(with: value), hard, value)
            XCTAssertEqual(NSPredicate.deriviationPathHardPassword.evaluate(with: value), hardPassword, value)
        }
    }
    func testSeedRequiresExactlyThirtyTwoHexBytes() {
        let hex = String(repeating: "aB12", count: 16)
        for value in [hex, "0x" + hex] { XCTAssertTrue(NSPredicate.seed.evaluate(with: value)) }
        for value in ["", String(hex.dropLast()), hex + "0", "0X" + hex, "0x" + String(repeating: "g", count: 64), " " + hex] {
            XCTAssertFalse(NSPredicate.seed.evaluate(with: value), value)
        }
    }
    func testWebsocketValidationAcceptsPublicHostsAndRejectsPrivateOrMalformedEndpoints() {
        for value in ["wss://mof2.sora.org", "ws://example.org:9944/path?key=value", "//example.org", "wss://8.8.8.8:443", "wss://sub.example.org/"] {
            XCTAssertTrue(NSPredicate.websocket.evaluate(with: value), value)
        }
        for value in ["https://example.org", "example.org", "wss://localhost", "ws://127.0.0.1:9944", "ws://10.1.2.3", "ws://192.168.1.2", "ws://172.16.0.2", "ws://169.254.1.2", "ws://0.0.0.0", "wss://example.org/path with space"] {
            XCTAssertFalse(NSPredicate.websocket.evaluate(with: value), value)
        }
    }
    func testPersonNamesAllowUnicodeLettersAndInternalSeparators() {
        for name in ["Alice", "O'Connor", "Jean-Luc", "竹宮 誠", "Élodie", "Alice😀"] { XCTAssertTrue(NSPredicate.personName.evaluate(with: name), name) }
        for name in ["", " ", "123", "Alice1", "-Alice", "Alice-", " Alice", "😀"] { XCTAssertFalse(NSPredicate.personName.evaluate(with: name), name) }
        XCTAssertFalse(NSPredicate.personName.evaluate(with: 42)); XCTAssertFalse(NSPredicate.personName.evaluate(with: nil))
    }
    func testInvitationCodesApplyFoundationWidthNormalizationAndRejectSeparators() {
        for value in ["a", "A1b2", "Ａ", String(repeating: "Z", count: 16)] { XCTAssertTrue(NSPredicate.invitationCode.evaluate(with: value)) }
        for value in ["", String(repeating: "a", count: 17), "a-b", "a_b", " a", "a "] { XCTAssertFalse(NSPredicate.invitationCode.evaluate(with: value), value) }
    }
    func testEthereumAddressRequiresExactPrefixedHexWidth() {
        let address = "0x" + String(repeating: "aBcD", count: 10)
        XCTAssertTrue(NSPredicate.ethereumAddress.evaluate(with: address))
        for value in [String(address.dropFirst(2)), String(address.dropLast()), address + "0", "0X" + String(address.dropFirst(2)), "0x" + String(repeating: "z", count: 40)] {
            XCTAssertFalse(NSPredicate.ethereumAddress.evaluate(with: value))
        }
    }
    func testNetworkErrorsExposeLocalizedActionableTextWithoutResponsePayloads() {
        let secretResponse = Data("private backend diagnostics".utf8)
        let errors: [(NetworkResponseError, String)] = [
            (.authorizationError(secretResponse), "Authorization Failed"), (.internalServerError(secretResponse), "Internal error"),
            (.invalidParameters(secretResponse), "Invalid Parameters"), (.resourceNotFound(secretResponse), "Resource unavailable"),
            (.unexpectedStatusCode(599, secretResponse), "Unexpected Response Status"), (.accessForbidden(secretResponse), "403")
        ]
        for (error, title) in errors {
            let app: ErrorContent = error.toErrorContent(for: Locale(identifier: "en"))
            let wallet = (error as WalletErrorContentConvertible).toErrorContent(for: Locale(identifier: "en"))
            XCTAssertEqual(app.title, title); XCTAssertFalse(app.message.isEmpty)
            XCTAssertFalse(app.message.contains("private backend")); XCTAssertEqual(wallet.title, app.title); XCTAssertEqual(wallet.message, app.message)
            let defaultLocale: ErrorContent = error.toErrorContent(for: nil)
            XCTAssertFalse(defaultLocale.title.isEmpty); XCTAssertFalse(defaultLocale.message.isEmpty)
        }
    }
}
