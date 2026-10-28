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

enum TransactionContextKeys {
    static let extrinsicHash = "extrinsicHash"
    static let blockHash = "blockHash"
    static let referralTransactionType = "referralTransactionType"
    static let sender = "sender"
    static let referrer = "referrer"
    static let referral = "referral"
    static let era = "era"

    static let transactionType: String = "transaction_type"
    static let estimatedAmount: String = "estimatedAmount"
    static let slippage: String = "possibleSlippage"
    static let desire: String = "desiredOutput"
    static let marketType: String = "marketType"
    static let minMaxValue: String = "minMaxValue"
    
    //pools
    static let dex: String = "dex"
    static let shareOfPool: String = "shareOfPoo"
    static let firstAssetAmount: String = "firstAssetAmount"
    static let secondAssetAmount: String = "secondAssetAmount"
    static let firstReserves: String = "firstReserves"
    static let totalIssuances: String = "totalIssuances"
    static let directExchangeRateValue: String = "directExchangeRateValue"
    static let inversedExchangeRateValue: String = "inversedExchangeRateValue"
    static let sbApy: String = "sbApy"
    //demeter
    static let rewardAsset: String = "rewardAsset"
    static let isFarm: String = "isFarm"
    static let amount: String = "amount"
}

struct TransactionHistoryContext {
    static let cursor = "cursor"
    static let isComplete = "isComplete"

    let cursor: Int?
    let isComplete: Bool

    init(
        cursor: Int?,
        isComplete: Bool
    ) {
        self.isComplete = isComplete
        self.cursor = cursor
    }
}

extension TransactionHistoryContext {
    init(context: [String: Any]) {
        if let numericCursor = context[Self.cursor] as? Int,
           numericCursor > 0 {
            cursor = numericCursor
        } else if
            let stringCursor = context[Self.cursor] as? String,
            let numericCursor = Int(stringCursor),
            numericCursor > 0
        {
            cursor = numericCursor
        } else {
            cursor = 1
        }

        if let boolean = context[Self.isComplete] as? Bool {
            isComplete = boolean
        } else if let string = context[Self.isComplete] as? String {
            isComplete = Bool(string) ?? false
        } else {
            isComplete = false
        }
    }

    func toContext() -> [String: Any] {
        var context: [String: Any] = [Self.isComplete: String(isComplete)]

        if let cursor = cursor {
            context[Self.cursor] = cursor
        }

        return context
    }
}
