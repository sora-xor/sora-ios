/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import Cuckoo

class DayChangeHandlerTest: XCTestCase {

    func testDayChangeEventReceive() {
        // given

        let delegate = MockDayChangeHandlerDelegate()

        let dayChangeHandler = DayChangeHandler()
        dayChangeHandler.delegate = delegate

        // when

        let expectation = XCTestExpectation()

        stub(delegate) { stub in
            when(stub).handlerDidReceiveChange(any(DayChangeHandlerProtocol.self)).then { _ in
                expectation.fulfill()
            }
        }

        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: self)

        // then

        wait(for: [expectation], timeout: Constants.expectationDuration)
    }
}
