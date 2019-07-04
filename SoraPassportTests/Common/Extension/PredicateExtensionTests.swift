/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
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
}
