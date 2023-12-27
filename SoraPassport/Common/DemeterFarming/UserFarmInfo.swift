// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
