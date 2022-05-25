import Foundation

enum TransactionContextKeys {
    static let extrinsicHash = "extrinsicHash"
    static let era = "era"

    static let transactionType: String = "transaction_type"
    static let estimatedAmount: String = "estimatedAmount"
    static let slippage: String = "possibleSlippage"
    static let desire: String = "desiredOutput"
    static let marketType: String = "marketType"
    static let minMaxValue: String = "minMaxValue"
    
    //pools
    static let shareOfPool: String = "shareOfPoo"
    static let firstAssetAmount: String = "firstAssetAmount"
    static let secondAssetAmount: String = "secondAssetAmount"
    static let directExchangeRateValue: String = "directExchangeRateValue"
    static let inversedExchangeRateValue: String = "inversedExchangeRateValue"
    static let sbApy: String = "sbApy"
}

struct TransactionHistoryContext {
    static let cursor = "cursor"
    static let isComplete = "isComplete"

    let cursor: String?
    let isComplete: Bool

    init(
        cursor: String?,
        isComplete: Bool
    ) {
        self.isComplete = isComplete
        self.cursor = cursor
    }
}

extension TransactionHistoryContext {
    init(context: [String: String]) {
        cursor = context[Self.cursor] ?? nil
        isComplete = context[Self.isComplete].map { Bool($0) ?? false } ?? false
    }

    func toContext() -> [String: String] {
        var context = [Self.isComplete: String(isComplete)]

        if let cursor = cursor {
            context[Self.cursor] = cursor
        }

        return context
    }
}
