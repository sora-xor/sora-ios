/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct VotesData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case value = "votes"
        case lastReceived = "lastReceivedVotes"
    }

    var value: String
    var lastReceived: String?
}
