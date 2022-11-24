/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import CommonWallet
import UIKit

extension AssetTransactionStatus {
    var title: String {
        return R.string.localizable.walletTxDetailsStatus(preferredLanguages: .currentLocale)
    }

    var details: String {
        switch self {
        case .pending: return R.string.localizable.walletTxDetailsPending(preferredLanguages: .currentLocale)
        case .commited: return R.string.localizable.statusSuccess(preferredLanguages: .currentLocale)
        case .rejected: return R.string.localizable.statusError(preferredLanguages: .currentLocale)
        }
    }

    var image: UIImage? {
        switch self {
        case .pending: return R.image.iconTxPending()
        case .commited: return R.image.iconTxStatusSuccess()
        case .rejected: return R.image.iconTxStatusError()
        }
    }
}
