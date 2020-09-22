/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport

class PredicateExtensionTests: XCTestCase {
    func testPhonePredicate() {
        let predicate = NSPredicate.phone

        XCTAssertTrue(predicate.evaluate(with: "+12345678910"))
        XCTAssertTrue(predicate.evaluate(with: "+1234"))
        XCTAssertTrue(predicate.evaluate(with: "+123423908"))
        XCTAssertTrue(predicate.evaluate(with: "+121323405678920"))
        XCTAssertTrue(predicate.evaluate(with: "12345678910"))
        XCTAssertTrue(predicate.evaluate(with: "1234"))
        XCTAssertTrue(predicate.evaluate(with: "123423908"))
        XCTAssertTrue(predicate.evaluate(with: "121323405678920"))
        XCTAssertFalse(predicate.evaluate(with: "+021323405678920"))
        XCTAssertFalse(predicate.evaluate(with: "+121"))
        XCTAssertFalse(predicate.evaluate(with: "+1213234056789202"))
        XCTAssertFalse(predicate.evaluate(with: "-121323405678920"))
        XCTAssertFalse(predicate.evaluate(with: "+123.2"))
        XCTAssertFalse(predicate.evaluate(with: "+21(12)"))
        XCTAssertFalse(predicate.evaluate(with: ""))
    }

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

    func testPhoneCode() {
        let predicate = NSPredicate.phoneCode

        XCTAssertTrue(predicate.evaluate(with: "1234"))
        XCTAssertTrue(predicate.evaluate(with: "5555"))
        XCTAssertTrue(predicate.evaluate(with: "0000"))
        XCTAssertTrue(predicate.evaluate(with: "9900"))

        XCTAssertFalse(predicate.evaluate(with: ""))
        XCTAssertFalse(predicate.evaluate(with: "123"))
        XCTAssertFalse(predicate.evaluate(with: "12355"))
        XCTAssertFalse(predicate.evaluate(with: "123a"))
        XCTAssertFalse(predicate.evaluate(with: "123L"))
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
