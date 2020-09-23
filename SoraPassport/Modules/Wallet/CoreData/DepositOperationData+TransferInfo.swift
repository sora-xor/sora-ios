/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

enum DepositOperationDataError: Error {
    case invalidAmount
}

extension DepositOperationData {
    static func createForEthereumFromInfo(_ info: TransferInfo,
                                          transactionId: String,
                                          receiverName: String? = nil) throws
        -> DepositOperationData {
        guard
            let amount = info.context?[WalletOperationContextKey.ERC20Withdraw.balance],
            let depositAmount = AmountDecimal(string: amount) else {
            throw DepositOperationDataError.invalidAmount
        }

        let timestamp = Int64(Date().timeIntervalSince1970)

        let transferAmount: AmountDecimal?

        if info.source != info.destination {
            let soranetAmount: Decimal
            if let amount = info.context?[WalletOperationContextKey.SoranetTransfer.balance] {
                soranetAmount = Decimal(string: amount) ?? Decimal(0)
            } else {
                soranetAmount = Decimal(0)
            }

            let totalFee = info.fees.reduce(Decimal(0.0)) { (result, fee) in
                if fee.feeDescription.assetId == info.asset {
                    return result + fee.value.decimalValue
                } else {
                    return result
                }
            }

            transferAmount = AmountDecimal(value: soranetAmount + depositAmount.decimalValue - totalFee)
        } else {
            transferAmount = nil
        }

        return DepositOperationData(depositTransactionId: transactionId,
                                    transferTransactionId: nil,
                                    timestamp: timestamp,
                                    status: .depositPending,
                                    assetId: info.asset,
                                    sender: info.source,
                                    receiver: info.destination,
                                    receiverName: receiverName,
                                    depositAmount: depositAmount,
                                    transferAmount: transferAmount,
                                    fees: info.fees,
                                    note: info.details)
    }
}
