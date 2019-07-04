/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

extension WalletEmptyStateDataSource {
    static var history: WalletEmptyStateDataSource {
        let title = R.string.localizable.walletHistoryEmptyStateTitle()
        let image = R.image.transactionsEmptyState()
        return WalletEmptyStateDataSource(title: title, image: image)
    }

    static var search: WalletEmptyStateDataSource {
        let title = R.string.localizable.walletSearchEmptyStateTitle()
        let image = R.image.searchEmptyState()
        return WalletEmptyStateDataSource(title: title, image: image)
    }

    static var contacts: WalletEmptyStateDataSource {
        let title = R.string.localizable.walletContactsEmptyStateTitle()
        let image = R.image.transactionsEmptyState()
        return WalletEmptyStateDataSource(title: title, image: image)
    }
}
