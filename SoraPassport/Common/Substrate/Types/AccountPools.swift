// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import BigInt
import SSFUtils
import Foundation

struct AccountPools: ScaleDecodable {
    let assetIds: [String]

    init(scaleDecoder: ScaleDecoding) throws {
        var assetIds: [String] = []
        // remove hex Prefix '0x'
        _ = try scaleDecoder.readAndConfirm(count: 1)
        for _ in 0 ..< (scaleDecoder.remained / 32) {
            let item = try scaleDecoder.readAndConfirm(count: 32)
            assetIds.append(item.toHex(includePrefix: true))
        }

        self.assetIds = assetIds
    }
}

struct PoolReserves: ScaleDecodable {
    let reserves: Balance
    let fees: Balance

    init(scaleDecoder: ScaleDecoding) throws {
        reserves = try Balance(scaleDecoder: scaleDecoder)
        fees = try Balance(scaleDecoder: scaleDecoder)
    }

    init(reserves: BigUInt = 0, fees: BigUInt = 0) {
        self.reserves = Balance(value: reserves)
        self.fees = Balance(value: fees)
    }
}

struct PoolProviders: ScaleDecodable {
    let reserves: Balance
    let fees: Balance

    init(scaleDecoder: ScaleDecoding) throws {
        reserves = try Balance(scaleDecoder: scaleDecoder)
        fees = try Balance(scaleDecoder: scaleDecoder)
    }

    init(reserves: BigUInt = 0, fees: BigUInt = 0) {
        self.reserves = Balance(value: reserves)
        self.fees = Balance(value: fees)
    }
}

struct PoolProperties: ScaleDecodable {
    let reservesAccountId: AccountId
    let feesAccountId: AccountId

    init(scaleDecoder: ScaleDecoding) throws {
        reservesAccountId = try AccountId(scaleDecoder: scaleDecoder)
        feesAccountId = try AccountId(scaleDecoder: scaleDecoder)
    }

    init(reservesAccountId: AccountId, feesAccountId: AccountId) {
        self.reservesAccountId = reservesAccountId
        self.feesAccountId = feesAccountId
    }
}

struct PoolDetails: Equatable {
    let baseAsset: String
    let targetAsset: String
    let yourPoolShare: Decimal
    let baseAssetPooledByAccount: Decimal
    let targetAssetPooledByAccount: Decimal
    let baseAssetPooledTotal: Decimal
    let targetAssetPooledTotal: Decimal
    let totalIssuances: Decimal
    let baseAssetReserves: Decimal
    let targetAssetReserves: Decimal
    let accountPoolBalance: Decimal
    let farms: [UserFarm]
}

struct OrmlAccountData: ScaleDecodable {
    let free: Balance
    let frozen: Balance
    let reserved: Balance

    init(scaleDecoder: ScaleDecoding) throws {
        free = try Balance(scaleDecoder: scaleDecoder)
        frozen = try Balance(scaleDecoder: scaleDecoder)
        reserved = try Balance(scaleDecoder: scaleDecoder)
    }
}
