import Foundation
import SoraFoundation

extension WalletEmptyStateDataSource {
    static var history: WalletEmptyStateDataSource {
        let title = LocalizableResource { locale in
            R.string.localizable.walletEmptyDescription(preferredLanguages: locale.rLanguages)
        }

        let image = R.image.iconEmptyDots()
        let dataSource = WalletEmptyStateDataSource(titleResource: title, image: image)
        dataSource.localizationManager = LocalizationManager.shared
        dataSource.verticalSpacingForEmptyState = 18
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
            R.string.localizable.emptyRecentRecipients2(preferredLanguages: locale.rLanguages)
        }

        let image = R.image.iconEmptyDots()
        let dataSource = WalletEmptyStateDataSource(titleResource: title, image: image)
        dataSource.localizationManager = LocalizationManager.shared

        return dataSource
    }

    static var searchAssets: WalletEmptyStateDataSource {
        let title = LocalizableResource { locale in
            R.string.localizable.assetNotFound(preferredLanguages: locale.rLanguages)
        }

        let image = R.image.iconWarningBig()
        let dataSource = WalletEmptyStateDataSource(titleResource: title, image: image)
        dataSource.localizationManager = LocalizationManager.shared

        return dataSource
    }
}
