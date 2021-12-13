import Foundation
import CommonWallet
import SoraFoundation

final class WalletConfirmationConfigurator {

    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            viewModelFactory.commandFactory
        }

        set {
            viewModelFactory.commandFactory = newValue
        }
    }

    let viewModelFactory: WalletConfirmationViewModelFactory

    init(assets: [WalletAsset],assetManager: AssetManagerProtocol, amountFormatterFactory: NumberFormatterFactoryProtocol) {
        viewModelFactory = WalletConfirmationViewModelFactory(assets: assets,
                                                              assetManager: assetManager,
                                                           amountFormatterFactory: amountFormatterFactory)
    }

    func configure(builder: TransferConfirmationModuleBuilderProtocol) {
        let title = LocalizableResource { locale in
            R.string.localizable.transactionConfirm(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(localizableTitle: title)
            .with(accessoryViewType: .onlyActionBar)
            .with(completion: .hide)
            .with(viewModelFactoryOverriding: viewModelFactory)
            .with(viewBinder: WalletConfirmationViewBinder())
            .with(definitionFactory: WalletSoraDefinitionFactory())
            .with(accessoryViewFactory: WalletSingleActionAccessoryFactory.self)
    }

}
