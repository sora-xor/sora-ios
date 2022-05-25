/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto

struct CoingeckoAPI {
    static let baseURL = URL(string: "https://api.coingecko.com/api/v3")!
    static let price = "simple/price"
}

extension WalletAssetId {
    var coingeckoTokenId: String? {
        switch self {
        default:
            return nil
        }
    }
}
