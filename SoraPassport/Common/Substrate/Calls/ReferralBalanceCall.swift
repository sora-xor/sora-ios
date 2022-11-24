/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import FearlessUtils
import BigInt

struct ReferralBalanceCall: Codable {
    @StringCodable var balance: BigUInt

    enum CodingKeys: String, CodingKey {
        case balance = "balance"
    }
}
