import Foundation

public struct AssetTransactionPageData: Equatable {
    public let transactions: [AssetTransactionData]
    public let context: PaginationContext?

    public init(
        transactions: [AssetTransactionData],
        context: PaginationContext? = nil
    ) {
        self.transactions = transactions
        self.context = context
    }
}

public typealias PaginationContext = [String: String]
