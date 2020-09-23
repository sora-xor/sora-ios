/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

struct WalletWithdrawMetadata: Codable {
    let providerAccountId: String
    let feeAccountId: String?
    let feeType: String
    let feeRate: AmountDecimal
}
