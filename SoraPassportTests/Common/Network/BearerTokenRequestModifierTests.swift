/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import XCTest
@testable import SoraPassport
import RobinHood

class BearerTokenRequestModifierTests: XCTestCase {

    func testHeaderSuccessfullySet() {
        do {
            // given
            let token = UUID().uuidString

            // when

            let requestModifier = BearerTokenRequestModifier(token: token)

            let request = URLRequest(url: Constants.dummyNetworkURL)
            var modifiedRequest = try requestModifier.modify(request: request)

            // then

            XCTAssertNotEqual(request, modifiedRequest)

            modifiedRequest.setValue(nil, forHTTPHeaderField: HttpHeaderKey.authorization.rawValue)

            XCTAssertEqual(request, modifiedRequest)

        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
