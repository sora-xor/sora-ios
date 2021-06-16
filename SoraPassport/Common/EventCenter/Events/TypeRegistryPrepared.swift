/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct TypeRegistryPrepared: EventProtocol {
    let version: UInt32

    func accept(visitor: EventVisitorProtocol) {
        visitor.processTypeRegistryPrepared(event: self)
    }
}
