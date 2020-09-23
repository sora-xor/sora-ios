/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

struct WalletTransferMetadata: Codable {
    let feeAccountId: String?
    let feeType: String
    let feeRate: AmountDecimal
}
