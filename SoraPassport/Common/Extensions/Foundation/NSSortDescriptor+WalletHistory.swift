/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension NSSortDescriptor {
    static var transfer: NSSortDescriptor {
        return NSSortDescriptor(key: #keyPath(CDTransfer.timestamp), ascending: false)
    }

    static var withdraw: NSSortDescriptor {
        return NSSortDescriptor(key: #keyPath(CDWithdraw.timestamp), ascending: false)
    }

    static var deposit: NSSortDescriptor {
        return NSSortDescriptor(key: #keyPath(CDDeposit.timestamp), ascending: false)
    }
}
