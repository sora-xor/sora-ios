/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

struct ReputationData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case reputation
        case rank
        case ranksCount = "totalRank"
    }

    var reputation: String?
    var rank: UInt?
    var ranksCount: UInt?
}
