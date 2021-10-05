/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct WalletNewTransactionInserted: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processNewTransaction(event: self)
    }
}
