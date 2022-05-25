/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct WalletStakingInfoChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processStakingChanged(event: self)
    }
}
