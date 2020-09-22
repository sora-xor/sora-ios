/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

extension WalletEmptyStateDataSource {
    static var history: WalletEmptyStateDataSource {
        let title = LocalizableResource { locale in
            R.string.localizable.walletEmptyDescription(preferredLanguages: locale.rLanguages)
        }

        let image = R.image.transactionsEmptyState()
        let dataSource = WalletEmptyStateDataSource(titleResource: title, image: image)
        dataSource.localizationManager = LocalizationManager.shared

        return dataSource
    }

    static var search: WalletEmptyStateDataSource {
        let title = LocalizableResource { locale in
            R.string.localizable.contactsSearchEmptyStateTitle(preferredLanguages: locale.rLanguages)
        }

        let image = R.image.searchEmptyState()
        let dataSource = WalletEmptyStateDataSource(titleResource: title, image: image)
        dataSource.localizationManager = LocalizationManager.shared

        return dataSource
    }

    static var contacts: WalletEmptyStateDataSource {
        let title = LocalizableResource { locale in
            R.string.localizable.contactsEmptyStateTitle(preferredLanguages: locale.rLanguages)
        }

        let image = R.image.transactionsEmptyState()
        let dataSource = WalletEmptyStateDataSource(titleResource: title, image: image)
        dataSource.localizationManager = LocalizationManager.shared

        return dataSource
    }
}
