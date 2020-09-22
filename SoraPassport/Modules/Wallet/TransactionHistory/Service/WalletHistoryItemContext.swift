/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct WalletHistoryItemContextKey {
    static let ethereumTxId: String = "ethereumTxId"
    static let soranetTxId: String = "soranetTxId"
}

typealias WalletHistoryItemContext = [String: String]

extension WalletHistoryItemContext {
    var soranetTxId: String? {
        self[WalletHistoryItemContextKey.soranetTxId]
    }

    var ethereumTxId: String? {
        self[WalletHistoryItemContextKey.ethereumTxId]
    }

    init(item: WalletRemoteHistoryItemData) {
        if let type = WalletTransactionTypeValue(rawValue: item.type) {
            switch type {
            case .incoming, .outgoing, .reward, .withdraw:
                self = [
                    WalletHistoryItemContextKey.soranetTxId: item.transactionId
                ]
            case .deposit:
                if NSPredicate.ethereumAddress.evaluate(with: item.details) {
                    self = [
                        WalletHistoryItemContextKey.soranetTxId: item.transactionId,
                        WalletHistoryItemContextKey.ethereumTxId: item.details
                    ]
                } else {
                    self = [
                        WalletHistoryItemContextKey.soranetTxId: item.transactionId
                    ]
                }
            }
        } else {
            self = [:]
        }
    }

    init(transfer: TransferOperationData) {
        self = [
            WalletHistoryItemContextKey.ethereumTxId: transfer.transactionId
        ]
    }

    init(withdraw: WithdrawOperationData) {
        if let transferTxId = withdraw.transferTransactionId {
            self = [
                WalletHistoryItemContextKey.ethereumTxId: transferTxId,
                WalletHistoryItemContextKey.soranetTxId: withdraw.intentTransactionId
            ]
        } else if let confirmationTxId = withdraw.confirmationTransactionId {
            self = [
                WalletHistoryItemContextKey.ethereumTxId: confirmationTxId,
                WalletHistoryItemContextKey.soranetTxId: withdraw.intentTransactionId
            ]
        } else {
            self = [
                WalletHistoryItemContextKey.soranetTxId: withdraw.intentTransactionId
            ]
        }
    }

    init(deposit: DepositOperationData) {
        if let transferTxId = deposit.transferTransactionId {
            self = [
                WalletHistoryItemContextKey.soranetTxId: transferTxId,
                WalletHistoryItemContextKey.ethereumTxId: deposit.depositTransactionId
            ]
        } else {
            self = [
                WalletHistoryItemContextKey.ethereumTxId: deposit.depositTransactionId
            ]
        }
    }
}
