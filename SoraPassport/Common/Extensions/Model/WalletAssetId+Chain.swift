/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto

extension WalletAssetId {
    var chain: Chain? {
        switch self {
        case .xor:
            return .sora
        case .val:
            return .sora
        case .pswap:
            return .sora
        }
    }

    var subqueryHistoryUrl: URL? {
        #if F_RELEASE
            return URL(string: "https://api.subquery.network/sq/sora-xor/sora")
        #elseif F_STAGING
            return URL(string: "https://api.subquery.network/sq/sora-xor/sora-staging")
        #elseif F_TEST
            return URL(string: "https://api.subquery.network/sq/sora-xor/sora-staging")
        #else
            return URL(string: "https://subquery.q1.dev.sora2.soramitsu.co.jp/")
        #endif
    }

    var defaultSort: Int? {
        switch self {
        case .xor:
            return 0
        case .val:
            return 1
        case .pswap:
            return 2
        default:
            return nil
        }
    }

    var chainId: String {
        switch self {
        case .pswap:
            return "0x0200050000000000000000000000000000000000000000000000000000000000"
        case .val:
            return "0x0200040000000000000000000000000000000000000000000000000000000000"
        case .xor:
            return "0x0200000000000000000000000000000000000000000000000000000000000000"
        }
    }

    var isFeeAsset: Bool {
        switch self {
        case .xor:
            return true
        default:
            return false
        }
    }
}
