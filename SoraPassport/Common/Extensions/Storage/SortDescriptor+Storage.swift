/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension NSSortDescriptor {
    static var accountsByOrder: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDAccountItem.order), ascending: true)
    }

    static var connectionsByOrder: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDConnectionItem.order), ascending: true)
    }

    static var contactsByTime: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDContactItem.updatedAt), ascending: false)
    }
}
