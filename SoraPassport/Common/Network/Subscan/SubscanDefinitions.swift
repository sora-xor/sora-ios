/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto

struct SubscanApi {
    static let price = "api/open/price"
    static let history = "api/scan/transfers"
}

extension WalletAssetId {
    var subscanUrl: URL? {
        switch self {
//        case .dot:
//            return URL(string: "https://polkadot.subscan.io/")
//        case .kusama:
//            return URL(string: "https://kusama.subscan.io/")
//        case .westend:
//            return URL(string: "https://westend.subscan.io/")
        default:
            return nil
        }
    }

    var hasPrice: Bool {
        switch self {
        default:
            return false
//        case .dot, .kusama:
//            return true
//        case .usd, .westend:
//            return false
        }
    }
}
