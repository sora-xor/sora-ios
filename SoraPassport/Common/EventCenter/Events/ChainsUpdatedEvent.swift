/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct ChainsUpdatedEvent: EventProtocol {
    let updatedChains: [ChainModel]

    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainsUpdated(event: self)
    }
}
