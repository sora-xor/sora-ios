/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

struct ProjectVote: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case projectId
        case votes
    }

    var projectId: String
    var votes: String
}
