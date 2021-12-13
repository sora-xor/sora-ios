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
    let operationManager: OperationManagerProtocol
    let localizationManager: LocalizationManagerProtocol
    let tokenFormatter: LocalizableResource<TokenFormatter>

    init(commandFactory: WalletCommandFactoryProtocol,
         operationManager: OperationManagerProtocol,
         localizationManager: LocalizationManagerProtocol,
         address: String,
         xorAddress: String,
         balance: BalanceData,
         tokenFormatter: LocalizableResource<TokenFormatter>) {
        self.commandFactory = commandFactory
        self.operationManager = operationManager
        self.localizationManager = localizationManager
        self.address = address
        self.xorAddress = xorAddress
        self.balance = balance
        self.tokenFormatter = tokenFormatter
    }

    func execute() throws {
        let locale = localizationManager.selectedLocale

        let alertView = UIAlertController(
            title: R.string.localizable.commonSelectOption(preferredLanguages: locale.rLanguages),
            message: nil, preferredStyle: .actionSheet
        )

        let copyXorTitle = R.string.localizable.copyValTitle(preferredLanguages: locale.rLanguages)
        let copyXorAction = UIAlertAction(title: copyXorTitle, style: .default) { [weak self] _ in
            UIPasteboard.general.string = self?.xorAddress
        }

        alertView.addAction(copyXorAction)

        let copyTitle = R.string.localizable.copyEthTitle(preferredLanguages: locale.rLanguages)
        let copyAction = UIAlertAction(title: copyTitle, style: .default) { [weak self] _ in
            UIPasteboard.general.string = self?.address
        }

        alertView.addAction(copyAction)

        let viewBalanceTitle = R.string.localizable.viewBalanceVal(preferredLanguages: locale.rLanguages)

        let viewBalanceAction = UIAlertAction(title: viewBalanceTitle, style: .default) { [weak self] _ in
           try? self?.showBalance()
        }

        alertView.addAction(viewBalanceAction)

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
            let xorPart = R.string.localizable.assetDetailsVal(preferredLanguages: locale.rLanguages)
            allocationView.headerLabel.text = R.string.localizable
                .valBalanceTitle(preferredLanguages: locale.rLanguages)
            allocationView.ethTitleLabel.text = R.string.localizable
                .assetEthPlaform(preferredLanguages: locale.rLanguages)  + " " +  xorPart
            allocationView.soraTitleLabel.text = R.string.localizable
                .assetXorPlatform(preferredLanguages: locale.rLanguages) + " " + xorPart
            allocationView.ethValueLabel.text = tokenFormatter.value(for: locale)
                .stringFromDecimal(Decimal(string: ercBalance) ?? 0)
            allocationView.soraValueLabel.text = tokenFormatter.value(for: locale)
                .stringFromDecimal(Decimal(string: xorBalance) ?? 0)

            view = allocationView
        }

        let viewController = UIViewController()
        viewController.preferredContentSize = CGSize(width: 0.0, height: view.frame.height)
        viewController.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.sora)
        viewController.modalTransitioningFactory = factory
        viewController.modalPresentationStyle = .custom

        try commandFactory.preparePresentationCommand(for: viewController).execute()
    }
}
