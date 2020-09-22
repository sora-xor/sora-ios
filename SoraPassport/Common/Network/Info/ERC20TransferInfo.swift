/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import BigInt

struct ERC20TransferInfo {
    let tokenAddress: Data
    let destinationAddress: Data
    let amount: BigUInt
}
