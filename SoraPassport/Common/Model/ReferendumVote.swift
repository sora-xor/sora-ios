/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum ReferendumVotingCase: Int, Encodable {
    case support
    case unsupport
}

struct ReferendumVote: Encodable {
    let referendumId: String
    let votes: String
    let votingCase: ReferendumVotingCase
}
