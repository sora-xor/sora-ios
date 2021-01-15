/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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

        var fees = info.fees
        #if !F_RELEASE
        if
        let index = fees.firstIndex(where: { $0.feeDescription.identifier == WalletNetworkConstants.ethFeeIdentifier }),
        let multiplier = Decimal(string: info.details) {
            let fee = info.fees[index]
            let params = fee.feeDescription.parameters
            let result = AmountDecimal(value: params.mintGas.decimalValue * multiplier)

            let updatedFee = Fee(value: fee.value,
                                 feeDescription: FeeDescription(identifier: fee.feeDescription.identifier,
                                                                assetId: fee.feeDescription.assetId,
                                                                type: fee.feeDescription.type,
                                                                parameters: EthFeeParameters(transferGas: params.transferGas,
                                                                                             mintGas: result,
                                                                                             gasPrice: params.gasPrice,
                                                                                             balance: params.balance),
                                                                accountId: fee.feeDescription.accountId,
                                                                minValue: fee.feeDescription.minValue,
                                                                maxValue: fee.feeDescription.maxValue,
                                                                context: fee.feeDescription.context))
            fees[index] = updatedFee

        }
        #endif
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
                                     fees: fees)
    }
}
