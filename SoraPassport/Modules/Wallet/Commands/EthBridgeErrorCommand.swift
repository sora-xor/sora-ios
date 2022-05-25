import Foundation
import CommonWallet
import RobinHood
import SoraFoundation
import SoraUI

final class EthBridgeErrorCommand: WalletCommandDecoratorProtocol {
    var undelyingCommand: WalletCommandProtocol?

    let commandFactory: WalletCommandFactoryProtocol
    let locale: Locale

    init(commandFactory: WalletCommandFactoryProtocol,
         locale: Locale) {
        self.commandFactory = commandFactory
        self.locale = locale
    }

    func execute() {
        try? showMessage()
    }

    let link = "https://github.com/sora-xor/VAL-bridge-activation"

    func showMessage() throws {
        var view = UIView()
        if let allocationView = R.nib.explainingCommandView(owner: nil, options: nil) {
            allocationView.headerLabel.text = R.string.localizable
                .transactionBridgeNotActiveError(preferredLanguages: locale.rLanguages)
            allocationView.soraTitleLabel.text = R.string.localizable
                .transactionBridgeInfo(preferredLanguages: locale.rLanguages)
            allocationView.soraValueLabel.text = link.components(separatedBy: "//").last

            allocationView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openLink)))
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

    @objc func openLink() {
        if let url = URL(string: link) {
            UIApplication.shared.openURL(url)
        }
    }
}
