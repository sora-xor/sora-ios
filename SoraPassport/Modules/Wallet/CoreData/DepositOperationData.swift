/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood

struct DepositOperationData: Codable {
    enum Status: String, Codable {
        case depositPending
        case depositCommited
        case depositFailed
        case depositReceived
        case depositFinalized
        case transferPending
        case transferCompleted
        case transferFailed
    }

    let depositTransactionId: String
    let transferTransactionId: String?
    let timestamp: Int64
    let status: Status
    let assetId: String
    let sender: String
    let receiver: String
    let receiverName: String?
    let depositAmount: AmountDecimal
    let transferAmount: AmountDecimal?
    let fees: [Fee]
    let note: String?
}

extension DepositOperationData: RobinHood.Identifiable {
    var identifier: String { depositTransactionId }
}

extension DepositOperationData {
    func changingStatus(_ newStatus: DepositOperationData.Status) -> DepositOperationData {
        DepositOperationData(depositTransactionId: depositTransactionId,
                             transferTransactionId: transferTransactionId,
                             timestamp: timestamp,
                             status: newStatus,
                             assetId: assetId,
                             sender: sender,
                             receiver: receiver,
                             receiverName: receiverName,
                             depositAmount: depositAmount,
                             transferAmount: transferAmount,
                             fees: fees,
                             note: note)
    }

    func changing(newTransferId: String) -> DepositOperationData {
        DepositOperationData(depositTransactionId: depositTransactionId,
                             transferTransactionId: newTransferId,
                             timestamp: timestamp,
                             status: status,
                             assetId: assetId,
                             sender: sender,
                             receiver: receiver,
                             receiverName: receiverName,
                             depositAmount: depositAmount,
                             transferAmount: transferAmount,
                             fees: fees,
                             note: note)
    }
}
