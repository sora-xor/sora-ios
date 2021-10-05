/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FearlessUtils
import BigInt

struct BalanceDepositEvent: Decodable {
    let accountId: AccountAddress
    let amount: BigUInt

    init(from decoder: Decoder) throws {
        var unkeyedContainer = try decoder.unkeyedContainer()

        accountId = try unkeyedContainer.decode(AccountAddress.self)
        amount = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
    }
}
