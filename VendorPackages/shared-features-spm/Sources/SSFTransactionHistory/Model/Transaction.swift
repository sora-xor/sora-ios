import Foundation

public enum TransactionStatus: Int16, Codable {
    case pending
    case success
    case failed
}

public enum TransactionType: Int16, Codable {
    case sent
    case received
    case swapped
    case crossChainSwapped
    case poolIn
    case poolOut
    case farmIn
    case farmOut
    case bond
    case unbond
    case referralJoin
    case referralSet
    case bonded
    case unbonded
    case rewarded
    case unexpected
}

public struct Transaction {
    let txHash: String
    let blockHash: String
    let fee: Decimal?
    let status: TransactionStatus
    let timestamp: String
    let context: TransactionContext?
}

public struct HistoryPage {
    let transactions: [Transaction]
    let errorMessage: String?
    let endReached: Bool

    init(transactions: [Transaction], endReached: Bool, errorMessage: String? = nil) {
        self.transactions = transactions
        self.endReached = endReached
        self.errorMessage = errorMessage
    }
}
