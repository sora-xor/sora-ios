import Foundation
import CommonWallet

extension TransferOperationData {
    static func createForEthereumFromInfo(_ info: TransferInfo, transactionId: String) throws
        -> TransferOperationData {

        let timestamp = Int64(Date().timeIntervalSince1970)

        return TransferOperationData(transactionId: transactionId,
                                     category: .ethereum,
                                     status: .pending,
                                     timestamp: timestamp,
                                     receiver: info.destination,
                                     receiverName: nil,
                                     sender: info.source,
                                     assetId: info.asset,
                                     amount: info.amount,
                                     fees: info.fees,
                                     note: info.details)
    }
}
