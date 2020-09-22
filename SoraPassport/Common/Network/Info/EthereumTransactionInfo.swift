/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import BigInt

struct EthereumTransactionInfo {
    let txData: Data
    let gasPrice: BigUInt
    let gasLimit: BigUInt
    let nonce: BigUInt
}
