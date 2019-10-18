/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct VerificationCodeData: Decodable {
    enum CodingKeys: String, CodingKey {
        case status
        case delay = "blockingTime"
    }

    var status: StatusData
    var delay: Int?
}
