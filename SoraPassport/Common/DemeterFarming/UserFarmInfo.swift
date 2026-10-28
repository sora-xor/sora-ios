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

import Foundation
import SSFUtils
import BigInt

struct UserFarmInfo: Codable, Equatable {
    var baseAsset: AssetId
    var poolAsset: AssetId
    var rewardAsset: AssetId
    var isFarm: Bool
    @StringCodable var pooledTokens: BigUInt
    @StringCodable var rewards: BigUInt
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.baseAsset.value == rhs.baseAsset.value &&
        lhs.poolAsset.value == rhs.poolAsset.value &&
        lhs.rewardAsset.value == rhs.rewardAsset.value
    }
}

struct UserFarm: Codable, Equatable {
    var id: String
    var baseAssetId: String
    var poolAssetId: String
    var rewardAssetId: String
    var isFarm: Bool
    var pooledTokens: Decimal? = nil
    var rewards: Decimal? = nil
    var stakedPercent: Decimal? = nil
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.baseAssetId == rhs.baseAssetId &&
        lhs.poolAssetId == rhs.poolAssetId &&
        lhs.rewardAssetId == rhs.rewardAssetId
    }
}

struct FarmedPoolInfo: Decodable {
    var multiplier: String
    @StringCodable var depositFee: BigUInt
    var isCore: Bool
    var isFarm: Bool
    @StringCodable var totalTokensInPool: BigUInt
    @StringCodable var rewards: BigUInt
    @StringCodable var rewardsToBeDistributed: BigUInt
    var isRemoved: Bool
    var baseAsset: AssetId
}

struct FarmedPool {
    let baseAssetId: String
    let poolAssetId: String
    let rewardAssetId: String
    let multiplier: Decimal
    let depositFee: Decimal
    let isCore: Bool
    let isFarm: Bool
    let totalTokensInPool: Decimal
    let rewards: Decimal
    let rewardsToBeDistributed: Decimal
    let isRemoved: Bool
}

struct FarmedTokenInfo: Decodable {
    var farmsTotalMultiplier: String
    var stakingTotalMultiplier: String
    @StringCodable var tokenPerBlock: BigUInt
    @StringCodable var farmsAllocation: BigUInt
    @StringCodable var stakingAllocation: BigUInt
}

struct FarmedRewardTokenInfo {
    let assetId: String
    let farmsTotalMultiplier: Decimal
    let stakingTotalMultiplier: Decimal
    let tokenPerBlock: Decimal
    let farmsAllocation: Decimal
    let stakingAllocation: Decimal
}

struct Farm {
    let id: String
    let name: String
    let baseAsset: AssetInfo?
    let poolAsset: AssetInfo?
    let rewardAsset: AssetInfo?
    let tvl: Decimal
    let apr: Decimal
    let depositFee: Decimal
}
