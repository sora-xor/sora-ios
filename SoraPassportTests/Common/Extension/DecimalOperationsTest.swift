/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport

class DecimalOperations: XCTestCase {

    func testRoundedStringFromDecimal() {
        let decimalValue: Decimal = 1212.23
        let rounded = decimalValue.rounded(mode: .down)
        XCTAssertEqual("1212", (rounded.stringWithPointSeparator))
    }

}
