/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import BigInt
import IrohaCrypto

extension AssetTransactionData {

    var transactionType: TransactionType {
        return TransactionType(rawValue: self.type) ?? TransactionType.extrinsic
    }
}
