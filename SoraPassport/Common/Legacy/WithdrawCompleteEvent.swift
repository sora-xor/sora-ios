/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

struct WithdrawCompleteEvent {
    let withdrawInfo: WithdrawInfo
}

extension WithdrawCompleteEvent: WalletEventProtocol {
    func accept(visitor: WalletEventVisitorProtocol) {
        visitor.processWithdrawComplete(event: self)
    }
}
