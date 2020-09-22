import Foundation
import CommonWallet

enum WithdrawOperationDataError: Error {
    case invalidAmount
}

extension WithdrawOperationData {
    static func createForEthereumFromInfo(_ info: TransferInfo, transactionId: String) throws
        -> WithdrawOperationData {
        guard
            let amount = info.context?[WalletOperationContextKey.SoranetWithdraw.balance],
            let withdrawAmount = AmountDecimal(string: amount) else {
            throw WithdrawOperationDataError.invalidAmount
        }

        let timestamp = Int64(Date().timeIntervalSince1970)

        let transferAmount: AmountDecimal?

        if let amountString = info.context?[WalletOperationContextKey.ERC20Transfer.balance] {
            guard let amount = Decimal(string: amountString) else {
                throw WithdrawOperationDataError.invalidAmount
            }

            transferAmount = AmountDecimal(value: withdrawAmount.decimalValue + amount)
        } else {
            transferAmount = nil
        }

        return WithdrawOperationData(intentTransactionId: transactionId,
                                     confirmationTransactionId: nil,
                                     transferTransactionId: nil,
                                     timestamp: timestamp,
                                     status: .intentSent,
                                     assetId: info.asset,
                                     sender: info.source,
                                     receiver: info.destination,
                                     receiverName: nil,
                                     withdrawAmount: withdrawAmount,
                                     transferAmount: transferAmount,
                                     fees: info.fees)
    }
}
