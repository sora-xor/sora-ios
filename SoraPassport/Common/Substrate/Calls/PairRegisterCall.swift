/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import FearlessUtils

struct PairRegisterCall: Codable {
    let dexId: String
    var baseAssetId: AssetId
    var targetAssetId: AssetId

    enum CodingKeys: String, CodingKey {
        case dexId = "dexId"
        case baseAssetId = "baseAssetId"
        case targetAssetId = "targetAssetId"
    }
}
