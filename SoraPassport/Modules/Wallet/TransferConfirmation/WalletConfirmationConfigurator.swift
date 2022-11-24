/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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

    func configure(builder: TransferConfirmationModuleBuilderProtocol, presenter: UIViewController) {
        let title = LocalizableResource { locale in
            R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages)
        }

        let titleProvider = LocalizableResource { locale in
            R.string.localizable.walletTransactionSubmitted(preferredLanguages: locale.rLanguages)
        }

        let alert = ModalAlertFactory.createAlert(titleProvider: titleProvider, image: R.image.success())

        builder
            .with(localizableTitle: title)
            .with(accessoryViewType: .onlyActionBar)
            .with(completion: .toast(view: alert, presenter: presenter))
            .with(viewModelFactoryOverriding: viewModelFactory)
            .with(viewBinder: WalletConfirmationViewBinder())
            .with(definitionFactory: WalletSoraDefinitionFactory())
            .with(accessoryViewFactory: WalletSingleActionAccessoryFactory.self)
    }

}
