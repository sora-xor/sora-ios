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
import BigInt

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
    enum AmountError: Error { case invalidPrecision, unrepresentable }

    private static func exactAmount(_ raw: BigUInt, precision: Int16) throws -> Decimal {
        guard (0...255).contains(precision) else { throw AmountError.invalidPrecision }
        if raw.isZero { return .zero }
        let digits = String(raw)
        let scale = Int(precision)
        let padded = String(repeating: "0", count: max(0, scale + 1 - digits.count)) + digits
        let split = padded.index(padded.endIndex, offsetBy: -scale)
        let text = scale == 0 ? padded : String(padded[..<split]) + "." + String(padded[split...])
        guard let value = Decimal.parseLocalizedAmount(text, locale: Locale(identifier: "en_US_POSIX")) else {
            throw AmountError.unrepresentable
        }
        return value
    }

    func byChangingAccountInfo(_ accountData: AccountData, precision: Int16) throws -> BalanceContext {
        let free = try Self.exactAmount(accountData.free, precision: precision)
        let reserved = try Self.exactAmount(accountData.reserved, precision: precision)
        let miscFrozen = try Self.exactAmount(accountData.miscFrozen, precision: precision)
        let feeFrozen = try Self.exactAmount(accountData.feeFrozen, precision: precision)

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
                               precision: Int16) throws -> BalanceContext {
        let redeemable = try Self.exactAmount(stakingInfo.redeemable(inEra: activeEra),
                                 precision: precision)

        let bonded = try Self.exactAmount(stakingInfo.active,
                                 precision: precision)

        let unbonding = try Self.exactAmount(stakingInfo.unbounding(inEra: activeEra),
                                 precision: precision)

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
