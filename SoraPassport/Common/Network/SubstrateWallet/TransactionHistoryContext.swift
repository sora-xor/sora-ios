/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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
