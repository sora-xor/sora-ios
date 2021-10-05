/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct ReferendumVoteEvent: EventProtocol {
    let vote: ReferendumVote

    func accept(visitor: EventVisitorProtocol) {
        visitor.processReferendumVote(event: self)
    }
}
