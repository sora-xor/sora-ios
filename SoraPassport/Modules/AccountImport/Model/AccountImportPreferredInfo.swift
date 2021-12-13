/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct AccountImportPreferredInfo {
    let username: String?
    let networkType: Chain?
    let cryptoType: CryptoType?
    let networkTypeConfirmed: Bool
}
