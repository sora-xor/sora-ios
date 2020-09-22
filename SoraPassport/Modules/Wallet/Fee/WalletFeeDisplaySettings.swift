import Foundation
import CommonWallet
import SoraFoundation

struct WalletFeeDisplaySettingsFactory: FeeDisplaySettingsFactoryProtocol {
    func createFeeSettingsForId(_ feeId: String) -> FeeDisplaySettingsProtocol {
        let feeDisplayStrategy = FeedDisplayStrategyIfNonzero()
        let displayName: LocalizableResource<String>
        let operationTitle: LocalizableResource<String>

        if feeId == WalletNetworkConstants.ethFeeIdentifier {
            displayName = LocalizableResource { locale in
                R.string.localizable.transactionMinerFeeTitle(preferredLanguages: locale.rLanguages)
            }

            operationTitle = LocalizableResource { locale in
                R.string.localizable.transactionMinerFeeTitle(preferredLanguages: locale.rLanguages)
            }
        } else {
            displayName = LocalizableResource { locale in
                R.string.localizable.transactionSoranetFeeTitle(preferredLanguages: locale.rLanguages)
            }

            operationTitle = LocalizableResource { locale in
                R.string.localizable.transactionSoranetFeeTitle(preferredLanguages: locale.rLanguages)
            }
        }

        return FeeDisplaySettings(displayStrategy: feeDisplayStrategy,
                                  displayName: displayName,
                                  operationTitle: operationTitle)
    }
}
