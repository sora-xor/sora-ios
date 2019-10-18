/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct ProjectVoteEvent: EventProtocol {
    let details: ProjectVote

    func accept(visitor: EventVisitorProtocol) {
        visitor.processProjectVote(event: self)
    }
}
