/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct VotesHistoryEventData: Codable, Equatable {
    var timestamp: Int64
    var message: String
    var votes: String
}
