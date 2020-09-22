import Foundation
import CommonWallet
import RobinHood

struct WithdrawOperationData: Codable {
    enum Status: String, Codable {
        case intentSent
        case intentPending
        case intentCompleted
        case intentFailed
        case intentFinalized
        case confirmationPending
        case confirmationCompleted
        case confirmationFailed
        case confirmationFinalized
        case transferPending
        case transferCompleted
        case transferFailed
    }

    let intentTransactionId: String
    let confirmationTransactionId: String?
    let transferTransactionId: String?
    let timestamp: Int64
    let status: Status
    let assetId: String
    let sender: String
    let receiver: String
    let receiverName: String?
    let withdrawAmount: AmountDecimal
    let transferAmount: AmountDecimal?
    let fees: [Fee]
}

extension WithdrawOperationData: RobinHood.Identifiable {
    var identifier: String { intentTransactionId }
}

extension WithdrawOperationData {
    func changingStatus(_ newStatus: WithdrawOperationData.Status) -> WithdrawOperationData {
        WithdrawOperationData(intentTransactionId: intentTransactionId,
                              confirmationTransactionId: confirmationTransactionId,
                              transferTransactionId: transferTransactionId,
                              timestamp: timestamp,
                              status: newStatus,
                              assetId: assetId,
                              sender: sender,
                              receiver: receiver,
                              receiverName: receiverName,
                              withdrawAmount: withdrawAmount,
                              transferAmount: transferAmount,
                              fees: fees)
    }

    func changing(newConfirmationId: String) -> WithdrawOperationData {
        WithdrawOperationData(intentTransactionId: intentTransactionId,
                              confirmationTransactionId: newConfirmationId,
                              transferTransactionId: transferTransactionId,
                              timestamp: timestamp,
                              status: status,
                              assetId: assetId,
                              sender: sender,
                              receiver: receiver,
                              receiverName: receiverName,
                              withdrawAmount: withdrawAmount,
                              transferAmount: transferAmount,
                              fees: fees)
    }

    func changing(transferId: String) -> WithdrawOperationData {
        WithdrawOperationData(intentTransactionId: intentTransactionId,
                              confirmationTransactionId: confirmationTransactionId,
                              transferTransactionId: transferId,
                              timestamp: timestamp,
                              status: status,
                              assetId: assetId,
                              sender: sender,
                              receiver: receiver,
                              receiverName: receiverName,
                              withdrawAmount: withdrawAmount,
                              transferAmount: transferAmount,
                              fees: fees)
    }
}
