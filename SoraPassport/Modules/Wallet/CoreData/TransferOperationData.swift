import Foundation
import CommonWallet
import RobinHood

struct TransferOperationData: Codable {
    enum Category: String, Codable {
        case ethereum
    }

    enum Status: String, Codable {
        case pending
        case completed
        case failed
    }

    let transactionId: String
    let category: Category
    let status: Status
    let timestamp: Int64
    let receiver: String
    let receiverName: String?
    let sender: String
    let assetId: String
    let amount: AmountDecimal
    let fees: [Fee]
    let note: String?
}

extension TransferOperationData: RobinHood.Identifiable {
    var identifier: String { transactionId }
}

extension TransferOperationData {
    func changingStatus(_ newStatus: TransferOperationData.Status) -> TransferOperationData {
        TransferOperationData(transactionId: transactionId,
                              category: category,
                              status: newStatus,
                              timestamp: timestamp,
                              receiver: receiver,
                              receiverName: receiverName,
                              sender: sender,
                              assetId: assetId,
                              amount: amount,
                              fees: fees,
                              note: note)
    }
}
