/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol UserApplicationServiceProtocol {
    func setup()
    func throttle()
}

protocol UserApplicationServiceFactoryProtocol {
    func createServices() -> [UserApplicationServiceProtocol]
}
