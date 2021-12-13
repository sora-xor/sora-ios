/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FearlessUtils
import BigInt

struct ValidatorExposure: Codable {
    @StringCodable var total: BigUInt
    @StringCodable var own: BigUInt
    let others: [IndividualExposure]
}

struct IndividualExposure: Codable {
    let who: Data
    @StringCodable var value: BigUInt
}
