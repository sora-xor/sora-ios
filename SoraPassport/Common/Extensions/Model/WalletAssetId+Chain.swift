import Foundation
import IrohaCrypto

extension WalletAssetId {
    var chain: Chain { .sora }

    static var subqueryHistoryUrl: URL {
        #if F_RELEASE
            return URL(string: "https://api.subquery.network/sq/sora-xor/sora")!
        #elseif F_STAGING
            return URL(string: "https://api.subquery.network/sq/sora-xor/sora-staging")!
        #elseif F_TEST
            return URL(string: "https://api.subquery.network/sq/sora-xor/sora-staging")!
        #else
            return URL(string: "https://api.subquery.network/sq/sora-xor/sora-dev")!
        #endif
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
        case .xstusd:
            return 3
        }
    }

    var chainId: String {
        return self.rawValue
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
