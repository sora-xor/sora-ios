/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import BigInt

struct EthereumWithdrawInfo {
    let txHash: Data
    let amount: BigUInt
    let proof: [EthereumSignature]
    let destination: String
}
