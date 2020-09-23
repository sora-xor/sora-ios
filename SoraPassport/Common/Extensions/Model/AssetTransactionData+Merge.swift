/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

extension AssetTransactionData {
    init(transfer: TransferOperationData) {
        let fees = transfer.fees.map { fee in
            AssetTransactionFee(identifier: fee.feeDescription.identifier,
                                assetId: fee.feeDescription.assetId,
                                amount: fee.value,
                                context: fee.feeDescription.context)
        }

        let context = WalletHistoryItemContext(transfer: transfer)

        self.init(transactionId: transfer.transactionId,
                  status: AssetTransactionStatus(transfer: transfer),
                  assetId: transfer.assetId,
                  peerId: transfer.receiver,
                  peerFirstName: nil,
                  peerLastName: nil,
                  peerName: transfer.receiver,
                  details: transfer.note ?? "",
                  amount: transfer.amount,
                  fees: fees,
                  timestamp: transfer.timestamp,
                  type: WalletTransactionTypeValue.outgoing.rawValue,
                  reason: nil,
                  context: context)
    }

    init(withdraw: WithdrawOperationData) {
        let type = withdraw.transferAmount != nil ? WalletTransactionTypeValue.outgoing :
        WalletTransactionTypeValue.withdraw

        let fees = withdraw.fees.map { fee in
            AssetTransactionFee(identifier: fee.feeDescription.identifier,
                                assetId: fee.feeDescription.assetId,
                                amount: fee.value,
                                context: fee.feeDescription.context)
        }

        let context = WalletHistoryItemContext(withdraw: withdraw)

        self.init(transactionId: withdraw.intentTransactionId,
                  status: AssetTransactionStatus(withdraw: withdraw),
                  assetId: withdraw.assetId,
                  peerId: withdraw.receiver,
                  peerFirstName: nil,
                  peerLastName: nil,
                  peerName: withdraw.receiver,
                  details: "",
                  amount: withdraw.transferAmount ?? withdraw.withdrawAmount,
                  fees: fees,
                  timestamp: withdraw.timestamp,
                  type: type.rawValue,
                  reason: nil,
                  context: context)
    }

    init(deposit: DepositOperationData) {
        let type = deposit.transferAmount != nil ? WalletTransactionTypeValue.outgoing :
        WalletTransactionTypeValue.deposit

        let fees = deposit.fees.map { fee in
            AssetTransactionFee(identifier: fee.feeDescription.identifier,
                                assetId: fee.feeDescription.assetId,
                                amount: fee.value,
                                context: fee.feeDescription.context)
        }

        let context = WalletHistoryItemContext(deposit: deposit)

        self.init(transactionId: deposit.depositTransactionId,
                  status: AssetTransactionStatus(deposit: deposit),
                  assetId: deposit.assetId,
                  peerId: deposit.receiver,
                  peerFirstName: nil,
                  peerLastName: nil,
                  peerName: deposit.receiverName,
                  details: deposit.note ?? "",
                  amount: deposit.transferAmount ?? deposit.depositAmount,
                  fees: fees,
                  timestamp: deposit.timestamp,
                  type: type.rawValue,
                  reason: nil,
                  context: context)
    }

    init(item: WalletRemoteHistoryItemData, accountId: String) {
        var fees: [AssetTransactionFee] = []

        if let feeValue = item.fee {
            let fee = AssetTransactionFee(identifier: item.assetId,
                                          assetId: item.assetId,
                                          amount: feeValue,
                                          context: nil)
            fees.append(fee)
        }

        let peerId: String
        let peerName: String?

        if let type = WalletTransactionTypeValue(rawValue: item.type) {
            switch type {
            case .deposit:
                peerId = accountId
                peerName = nil
            case .withdraw:
                if NSPredicate.ethereumAddress.evaluate(with: item.details) {
                    peerId = item.details
                } else {
                    peerId = item.peerId
                }
                peerName = nil
            default:
                peerId = item.peerId
                peerName = item.peerName
            }
        } else {
            peerId = item.peerId
            peerName = item.peerName
        }

        let context = WalletHistoryItemContext(item: item)

        self.init(transactionId: item.transactionId,
                  status: item.status,
                  assetId: item.assetId,
                  peerId: peerId,
                  peerFirstName: item.peerFirstName,
                  peerLastName: item.peerLastName,
                  peerName: peerName,
                  details: item.details,
                  amount: item.amount,
                  fees: fees,
                  timestamp: item.timestamp,
                  type: item.type,
                  reason: item.reason,
                  context: context)
    }
}

extension AssetTransactionStatus {
    init(deposit: DepositOperationData) {
        switch deposit.status {
        case .depositPending, .transferPending:
            self = .pending
        case .depositCommited, .depositReceived, .depositFinalized:
            if deposit.transferAmount == nil {
                self = .commited
            } else {
                self = .pending
            }
        case .depositFailed, .transferFailed:
            self = .rejected
        case .transferCompleted:
            self = .commited
        }
    }

    init(withdraw: WithdrawOperationData) {
        switch withdraw.status {
        case .intentSent, .intentPending, .intentCompleted, .intentFinalized,
             .confirmationPending, .transferPending:
            self = .pending
        case .confirmationCompleted, .confirmationFinalized:
            if withdraw.transferAmount == nil {
                self = .commited
            } else {
                self = .pending
            }
        case .transferCompleted:
            self = .commited
        case .intentFailed, .confirmationFailed, .transferFailed:
            self = .rejected
        }
    }

    init(transfer: TransferOperationData) {
        switch transfer.status {
        case .pending:
            self = .pending
        case .completed:
            self = .commited
        case .failed:
            self = .rejected
        }
    }
}
