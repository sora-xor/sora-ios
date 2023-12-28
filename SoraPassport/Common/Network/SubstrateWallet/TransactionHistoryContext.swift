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
        cursor = Int(context[Self.cursor] as? String ?? "1")
        isComplete = context[Self.isComplete].map { Bool($0 as? String ?? "false") ?? false } ?? false
    }

    func toContext() -> [String: Any] {
        var context: [String: Any] = [Self.isComplete: String(isComplete)]

        if let cursor = cursor {
            context[Self.cursor] = cursor
        }

        return context
    }
}
