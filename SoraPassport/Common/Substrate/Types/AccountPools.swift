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

import BigInt
import FearlessUtils

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
