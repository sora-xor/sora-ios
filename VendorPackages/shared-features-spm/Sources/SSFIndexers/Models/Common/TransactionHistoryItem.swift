import BigInt
import Foundation
import RobinHood
import SSFModels

public struct TransactionHistoryItem: Codable {
    public enum CodingKeys: String, CodingKey {
        case sender
        case receiver
        case status
        case txHash
        case timestamp
        case fee
        case blockNumber
        case txIndex
        case isTransfer
        case moduleName
        case callName
        case value
    }

    public enum Status: Int16, Codable {
        case pending
        case success
        case failed
    }

    public let sender: String
    public let receiver: String?
    public let status: Status
    public let txHash: String
    public let timestamp: Int64
    public let fee: String
    public let blockNumber: UInt64?
    public let txIndex: UInt16?
    public let isTransfer: Bool
    public let moduleName: String
    public let callName: String
    public let value: String
}

extension TransactionHistoryItem: Identifiable {
    public var identifier: String { txHash }
}

public extension TransactionHistoryItem.Status {
    var walletValue: AssetTransactionStatus {
        switch self {
        case .success:
            return .commited
        case .failed:
            return .rejected
        case .pending:
            return .pending
        }
    }
}
