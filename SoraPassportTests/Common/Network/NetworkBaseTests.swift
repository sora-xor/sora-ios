/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import XCTest
import RobinHood
@testable import SoraPassport

class NetworkBaseTests: XCTestCase {

    override func setUp() {
        NetworkMockManager.shared.enable()
    }

    override func tearDown() {
        NetworkMockManager.shared.disable()
    }
}
