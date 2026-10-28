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

struct DyAccountInfo: Codable, Equatable {
    @StringCodable var nonce: UInt32
    @StringCodable var consumers: UInt32
    @StringCodable var providers: UInt32
    let data: DyAccountData
}

struct DyAccountData: Codable, Equatable {
    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @StringCodable var miscFrozen: BigUInt
    @StringCodable var feeFrozen: BigUInt
}

extension DyAccountData {
    var total: BigUInt { free + reserved }
    var frozen: BigUInt { reserved + locked }
    var locked: BigUInt { max(miscFrozen, feeFrozen) }
    var available: BigUInt { free > locked ? free - locked : 0 }

    /// Accepts the balances layout of SORA2 runtime 119 and earlier
    /// (`misc_frozen`, `fee_frozen`) and of runtime 124 and later (`frozen`,
    /// `flags`); see `AccountData.init(from:)`.
    init(from decoder: Decoder) throws {
        let data = try AccountData(from: decoder)
        self.init(
            free: data.free,
            reserved: data.reserved,
            miscFrozen: data.miscFrozen,
            feeFrozen: data.feeFrozen
        )
    }
}
