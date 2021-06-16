/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol ReconnectionStrategyProtocol {
    func reconnectAfter(attempt: Int) -> TimeInterval?
}

struct ExponentialReconnection: ReconnectionStrategyProtocol {
    let multiplier: Double

    init(multiplier: Double = 0.3) {
        self.multiplier = multiplier
    }

    func reconnectAfter(attempt: Int) -> TimeInterval? {
        multiplier * exp(Double(attempt))
    }
}
