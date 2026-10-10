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

struct BalanceInfo: Decodable {
    @StringCodable var balance: BigUInt
}

struct Balance: ScaleCodable {
    let value: BigUInt

    init(value: BigUInt) {
        self.value = value
    }

    init(scaleDecoder: ScaleDecoding) throws {
        let data = try scaleDecoder.read(count: 16)
        value = BigUInt(Data(data.reversed()))
        try scaleDecoder.confirm(count: 16)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        var encodedData: [UInt8] = value.serialize().reversed()

        while encodedData.count < 16 {
            encodedData.append(0)
        }

        scaleEncoder.appendRaw(data: Data(encodedData))
    }
}


struct AccountInfo: Codable, Equatable {
    @StringCodable var nonce: UInt32
    @StringCodable var consumers: UInt32
    @StringCodable var providers: UInt32
    let data: AccountData

    init(nonce: UInt32, consumers: UInt32, providers: UInt32, data: AccountData) {
        self.nonce = nonce
        self.consumers = consumers
        self.providers = providers
        self.data = data
    }
//Left intentionally for later try to get other balances this way
//    init?(ormlAccountInfo: OrmlAccountInfo?) {
//        guard let ormlAccountInfo = ormlAccountInfo else {
//            return nil
//        }
//        nonce = 0
//        consumers = 0
//        providers = 0
//
//        data = AccountData(
//            free: ormlAccountInfo.free,
//            reserved: ormlAccountInfo.reserved,
//            miscFrozen: ormlAccountInfo.frozen,
//            feeFrozen: BigUInt.zero
//        )
//    }
}

struct AccountData: Codable, Equatable {
    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @StringCodable var miscFrozen: BigUInt
    @StringCodable var feeFrozen: BigUInt
}

extension AccountData {
    var total: BigUInt { free + reserved }
    var frozen: BigUInt { reserved + locked }
    var locked: BigUInt { max(miscFrozen, feeFrozen) }
    var available: BigUInt { free > locked ? free - locked : 0 }

    /// Decodes `System.Account` balances in both layouts SORA2 has used.
    /// Up to runtime 130 the balances pallet stored `free, reserved,
    /// misc_frozen, fee_frozen`. Runtime 132 and later store `free, reserved,
    /// frozen, flags`, where `frozen` is the amount that free plus reserved
    /// may not drop below. Without this, every XOR balance read as zero and
    /// the send flow could not read the recipient's account on runtime 133.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: BalancesLayoutKeys.self)
        let free = try container.decode(StringCodable<BigUInt>.self, forKey: .free).wrappedValue
        let reserved = try container.decode(StringCodable<BigUInt>.self, forKey: .reserved).wrappedValue
        if container.contains(.miscFrozen) || container.contains(.feeFrozen) {
            self.init(
                free: free,
                reserved: reserved,
                miscFrozen: try container.decode(StringCodable<BigUInt>.self, forKey: .miscFrozen).wrappedValue,
                feeFrozen: try container.decode(StringCodable<BigUInt>.self, forKey: .feeFrozen).wrappedValue
            )
        } else {
            let locked = BalancesLayoutKeys.lockedFreeBalance(
                free: free,
                reserved: reserved,
                frozen: try container.decode(StringCodable<BigUInt>.self, forKey: .frozen).wrappedValue
            )
            self.init(free: free, reserved: reserved, miscFrozen: locked, feeFrozen: locked)
        }
    }
}

/// Keys of the balances pallet's account data in its old
/// (`miscFrozen`/`feeFrozen`) and current (`frozen`/`flags`) layouts.
enum BalancesLayoutKeys: String, CodingKey {
    case free
    case reserved
    case miscFrozen
    case feeFrozen
    case frozen

    /// The part of `free` that cannot be moved under the current layout:
    /// `frozen` applies to free plus reserved, so only what is not covered by
    /// the reserved balance locks free balance, and never more than `free`.
    static func lockedFreeBalance(
        free: BigUInt,
        reserved: BigUInt,
        frozen: BigUInt
    ) -> BigUInt {
        let untouchable = frozen > reserved ? frozen - reserved : 0
        return min(untouchable, free)
    }
}
