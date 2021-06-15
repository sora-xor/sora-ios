/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import FearlessUtils
import BigInt

struct ValidatorPrefs: Codable {
    @StringCodable var commission: BigUInt
}
