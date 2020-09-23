/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood
import SoraFoundation
import SoraUI

final class XorAssetDetailsCommand: WalletCommandDecoratorProtocol {
    var undelyingCommand: WalletCommandProtocol?

    let balance: BalanceData

    let commandFactory: WalletCommandFactoryProtocol
    let address: String
    let xorAddress: String
    let dataProvider: StreamableProvider<EthereumInit>
    let repository: AnyDataProviderRepository<EthereumInit>
    let operationManager: OperationManagerProtocol
    let localizationManager: LocalizationManagerProtocol
    let tokenFormatter: LocalizableResource<TokenAmountFormatter>

    init(commandFactory: WalletCommandFactoryProtocol,
         dataProvider: StreamableProvider<EthereumInit>,
         repository: AnyDataProviderRepository<EthereumInit>,
         operationManager: OperationManagerProtocol,
         localizationManager: LocalizationManagerProtocol,
         address: String,
         xorAddress: String,
         balance: BalanceData,
         tokenFormatter: LocalizableResource<TokenAmountFormatter>) {
        self.commandFactory = commandFactory
        self.dataProvider = dataProvider
        self.repository = repository
        self.operationManager = operationManager
        self.localizationManager = localizationManager
        self.address = address
        self.xorAddress = xorAddress
        self.balance = balance
        self.tokenFormatter = tokenFormatter
    }

    func execute() throws {
        let locale = localizationManager.selectedLocale

        let alertView = UIAlertController(title: R.string.localizable.commonSelectOption(preferredLanguages: locale.rLanguages),
                                          message: nil,
                                          preferredStyle: .actionSheet)

        let copyXorTitle = R.string.localizable.copyXorTitle(preferredLanguages: locale.rLanguages)
        let copyXorAction = UIAlertAction(title: copyXorTitle, style: .default) { [weak self] _ in
            UIPasteboard.general.string = self?.xorAddress
        }

        alertView.addAction(copyXorAction)

// TODO: Temporary disabled until v1.7
//        let copyTitle = R.string.localizable.copy_eth_title(preferredLanguages: locale.rLanguages)
//        let copyAction = UIAlertAction(title: copyTitle, style: .default) { [weak self] _ in
//            UIPasteboard.general.string = self?.address
//        }
//
//        alertView.addAction(copyAction)

        // TODO: Temporary disabled until v1.7
        /*let viewBalanceTitle = R.string.localizable.view_balance(preferredLanguages: locale.rLanguages)

        let viewBalanceAction = UIAlertAction(title: viewBalanceTitle, style: .default) { [weak self] _ in
           try? self?.showBalance()
        }

        alertView.addAction(viewBalanceAction)*/

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
        alertView.addAction(cancelAction)

        try commandFactory.preparePresentationCommand(for: alertView).execute()
    }

    func showBalance() throws {
        var view = UIView()
        let locale = localizationManager.selectedLocale
        if let allocationView = R.nib.tokenAllocationView(owner: nil, options: nil),
            let context = balance.context,
            let ercBalance = context[WalletOperationContextKey.Balance.erc20],
            let xorBalance = context[WalletOperationContextKey.Balance.soranet] {
            let xorPart = R.string.localizable.assetDetails(preferredLanguages: locale.rLanguages)
            allocationView.headerLabel.text = R.string.localizable
                .xorBalanceTitle(preferredLanguages: locale.rLanguages)
            allocationView.ethTitleLabel.text = xorPart + " " + R.string.localizable
                .walletErc20(preferredLanguages: locale.rLanguages)
            allocationView.soraTitleLabel.text = xorPart + " " + R.string.localizable
                .walletSoranet(preferredLanguages: locale.rLanguages)
            allocationView.ethValueLabel.text = tokenFormatter.value(for: locale)
                .string(from: Decimal(string: ercBalance) ?? 0)
            allocationView.soraValueLabel.text = tokenFormatter.value(for: locale)
                .string(from: Decimal(string: xorBalance) ?? 0)

            view = allocationView
        }

        let viewController = UIViewController()
        viewController.preferredContentSize = CGSize(width: 0.0, height: view.frame.height)
        viewController.view = view

        let factory = ModalInputPresentationFactory(configuration: ModalInputPresentationConfiguration.sora)
        viewController.modalTransitioningFactory = factory
        viewController.modalPresentationStyle = .custom

        try commandFactory.preparePresentationCommand(for: viewController).execute()
    }
}
