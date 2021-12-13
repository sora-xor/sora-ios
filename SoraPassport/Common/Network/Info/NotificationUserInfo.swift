/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct NotificationUserInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case tokens = "pushTokens"
        case allowedDecentralizedIds = "didsForPermit"
    }

    var tokens: [String]
    var allowedDecentralizedIds: [String]
}
