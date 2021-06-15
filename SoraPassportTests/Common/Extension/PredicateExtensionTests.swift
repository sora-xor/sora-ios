import XCTest
@testable import SoraPassport

class PredicateExtensionTests: XCTestCase {

    func testInvitationCodePredicate() {
        let predicate = NSPredicate.invitationCode

        XCTAssertTrue(predicate.evaluate(with: "12345678"))
        XCTAssertTrue(predicate.evaluate(with: "12a4b67f"))
        XCTAssertTrue(predicate.evaluate(with: "asdadsaz"))
        XCTAssertTrue(predicate.evaluate(with: "asAaDs2z"))
        XCTAssertTrue(predicate.evaluate(with: "12a4b6712a4b6767"))
        XCTAssertFalse(predicate.evaluate(with: "123456п8"))
        XCTAssertFalse(predicate.evaluate(with: "12a4b6712a4b67679"))
        XCTAssertFalse(predicate.evaluate(with: ""))
    }

    func testEmpty() {
        let predicate = NSPredicate.empty
        XCTAssertTrue(predicate.evaluate(with: ""))
        XCTAssertFalse(predicate.evaluate(with: "1"))
    }

    func testPersonName() {
        let predicate = NSPredicate.personName

        XCTAssertTrue(predicate.evaluate(with: "John Gold"))
        XCTAssertTrue(predicate.evaluate(with: "John-Gold"))
        XCTAssertTrue(predicate.evaluate(with: "John'Gold"))
        XCTAssertTrue(predicate.evaluate(with: "Джон'Голд"))
        XCTAssertTrue(predicate.evaluate(with: "ДжонGold"))
        XCTAssertTrue(predicate.evaluate(with: "G"))
        XCTAssertTrue(predicate.evaluate(with: "д"))

        XCTAssertFalse(predicate.evaluate(with: ""))
        XCTAssertFalse(predicate.evaluate(with: " "))
        XCTAssertFalse(predicate.evaluate(with: "-"))
        XCTAssertFalse(predicate.evaluate(with: "'"))
        XCTAssertFalse(predicate.evaluate(with: " Gold"))
        XCTAssertFalse(predicate.evaluate(with: "-Gold"))
        XCTAssertFalse(predicate.evaluate(with: "'Gold"))
        XCTAssertFalse(predicate.evaluate(with: "Джон'"))
        XCTAssertFalse(predicate.evaluate(with: "Джон-"))
        XCTAssertFalse(predicate.evaluate(with: "Джон "))
    }
}
