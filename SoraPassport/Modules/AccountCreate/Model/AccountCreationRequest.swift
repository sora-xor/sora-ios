/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto
//
struct AccountCreationRequest {
    let username: String
    let type: Chain
    let derivationPath: String
    let cryptoType: CryptoType
}
