/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import FearlessUtils

struct InitializePoolCall: Codable {
    let dexId: String
    var assetA: AssetId
    var assetB: AssetId

    enum CodingKeys: String, CodingKey {
        case dexId = "dexId"
        case assetA = "assetA"
        case assetB = "assetB"
    }
}
