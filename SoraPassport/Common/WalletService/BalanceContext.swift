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

struct BalanceContext {
    static let freeKey = "account.balance.free.key"
    static let reservedKey = "account.balance.reserved.key"
    static let miscFrozenKey = "account.balance.misc.frozen.key"
    static let feeFrozenKey = "account.balance.fee.frozen.key"

    static let bondedKey = "account.balance.bonded.key"
    static let redeemableKey = "account.balance.redeemable.key"
    static let unbondingKey = "account.balance.unbonding.key"

    static let priceKey = "account.balance.price.key"
    static let priceChangeKey = "account.balance.price.change.key"

    let free: Decimal
    let reserved: Decimal
    let miscFrozen: Decimal
    let feeFrozen: Decimal

    let bonded: Decimal
    let redeemable: Decimal
    let unbonding: Decimal

    let price: Decimal
    let priceChange: Decimal
}

extension BalanceContext {
    var total: Decimal { free + reserved }
    var frozen: Decimal { reserved + locked }
    var locked: Decimal { max(miscFrozen, feeFrozen) }
    var available: Decimal { free - locked }
}

extension BalanceContext {
    init(context: [String: String]) {
        self.free = Self.parseContext(key: BalanceContext.freeKey, context: context)
        self.reserved = Self.parseContext(key: BalanceContext.reservedKey, context: context)
        self.miscFrozen = Self.parseContext(key: BalanceContext.miscFrozenKey, context: context)
        self.feeFrozen = Self.parseContext(key: BalanceContext.feeFrozenKey, context: context)

        self.bonded = Self.parseContext(key: BalanceContext.bondedKey, context: context)
        self.redeemable = Self.parseContext(key: BalanceContext.redeemableKey, context: context)
        self.unbonding  = Self.parseContext(key: BalanceContext.unbondingKey, context: context)

        self.price = Self.parseContext(key: BalanceContext.priceKey, context: context)
        self.priceChange = Self.parseContext(key: BalanceContext.priceChangeKey, context: context)
    }

    func toContext() -> [String: String] {
        [
            BalanceContext.freeKey: free.stringWithPointSeparator,
            BalanceContext.reservedKey: reserved.stringWithPointSeparator,
            BalanceContext.miscFrozenKey: miscFrozen.stringWithPointSeparator,
            BalanceContext.feeFrozenKey: feeFrozen.stringWithPointSeparator,
            BalanceContext.bondedKey: bonded.stringWithPointSeparator,
            BalanceContext.redeemableKey: redeemable.stringWithPointSeparator,
            BalanceContext.unbondingKey: unbonding.stringWithPointSeparator,
            BalanceContext.priceKey: price.stringWithPointSeparator,
            BalanceContext.priceChangeKey: priceChange.stringWithPointSeparator
        ]
    }

    private static func parseContext(key: String, context: [String: String]) -> Decimal {
        if let stringValue = context[key] {
            return Decimal(string: stringValue) ?? .zero
        } else {
            return .zero
        }
    }
}

extension BalanceContext {
    func byChangingAccountInfo(_ accountData: AccountData, precision: Int16) -> BalanceContext {
        let free = Decimal
            .fromSubstrateAmount(accountData.free, precision: precision) ?? .zero
        let reserved = Decimal
            .fromSubstrateAmount(accountData.reserved, precision: precision) ?? .zero
        let miscFrozen = Decimal
            .fromSubstrateAmount(accountData.miscFrozen, precision: precision) ?? .zero
        let feeFrozen = Decimal
            .fromSubstrateAmount(accountData.feeFrozen, precision: precision) ?? .zero

        return BalanceContext(free: free,
                              reserved: reserved,
                              miscFrozen: miscFrozen,
                              feeFrozen: feeFrozen,
                              bonded: bonded,
                              redeemable: redeemable,
                              unbonding: unbonding,
                              price: price,
                              priceChange: priceChange)
    }

    func byChangingStakingInfo(_ stakingInfo: StakingLedger,
                               activeEra: UInt32,
                               precision: Int16) -> BalanceContext {
        let redeemable = Decimal
            .fromSubstrateAmount(stakingInfo.redeemable(inEra: activeEra),
                                 precision: precision) ?? .zero

        let bonded = Decimal
            .fromSubstrateAmount(stakingInfo.active,
                                 precision: precision) ?? .zero

        let unbonding = Decimal
            .fromSubstrateAmount(stakingInfo.unbounding(inEra: activeEra),
                                 precision: precision) ?? .zero

        return BalanceContext(free: free,
                              reserved: reserved,
                              miscFrozen: miscFrozen,
                              feeFrozen: feeFrozen,
                              bonded: bonded,
                              redeemable: redeemable,
                              unbonding: unbonding,
                              price: price,
                              priceChange: priceChange)
    }

    func byChangingPrice(_ newPrice: Decimal, newPriceChange: Decimal) -> BalanceContext {
        BalanceContext(free: free,
                       reserved: reserved,
                       miscFrozen: miscFrozen,
                       feeFrozen: feeFrozen,
                       bonded: bonded,
                       redeemable: redeemable,
                       unbonding: unbonding,
                       price: newPrice,
                       priceChange: newPriceChange)
    }
}
