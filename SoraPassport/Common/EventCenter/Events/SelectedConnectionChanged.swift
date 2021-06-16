/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct SelectedConnectionChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processSelectedConnectionChanged(event: self)
    }
}
