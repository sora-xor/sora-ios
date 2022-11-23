/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import FearlessUtils

struct SetReferrerCall: Codable {
    let referrer: MultiAddress

    enum CodingKeys: String, CodingKey {
        case referrer = "referrer"
    }
}
