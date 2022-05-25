import Foundation
import CommonWallet
import SoraFoundation

final class WalletConfirmationConfigurator {
    let localizationManager: LocalizationManagerProtocol
    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            viewModelFactory.commandFactory
        }
        set {
            viewModelFactory.commandFactory = newValue
        }
    }

    let viewModelFactory: WalletConfirmationViewModelFactory

    init(assets: [WalletAsset], assetManager: AssetManagerProtocol, amountFormatterFactory: AmountFormatterFactoryProtocol,
         localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
        viewModelFactory = WalletConfirmationViewModelFactory(assets: assets,
                                                              assetManager: assetManager,
                                                           amountFormatterFactory: amountFormatterFactory)
    }

    func configure(builder: TransferConfirmationModuleBuilderProtocol) {
        let title = LocalizableResource { locale in
            R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages)
        }

        let alertTitle = R.string.localizable.walletTransactionSubmitted(preferredLanguages:
                                                                            self.localizationManager.selectedLocale.rLanguages)
        let alert = ModalAlertFactory.createSuccessAlert(alertTitle)

        builder
            .with(localizableTitle: title)
            .with(accessoryViewType: .onlyActionBar)
            .with(completion: .toast(view: alert, presenter: nil))
            .with(viewModelFactoryOverriding: viewModelFactory)
            .with(viewBinder: WalletConfirmationViewBinder())
            .with(definitionFactory: WalletSoraDefinitionFactory())
            .with(accessoryViewFactory: WalletSingleActionAccessoryFactory.self)
    }

}
