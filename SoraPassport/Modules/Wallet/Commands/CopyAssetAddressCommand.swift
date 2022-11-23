import Foundation
import CommonWallet
import RobinHood
import SoraFoundation

final class CopyAssetAddressCommand {
    var undelyingCommand: WalletCommandProtocol?

    let commandFactory: WalletCommandFactoryProtocol
    let address: String
    let localizationManager: LocalizationManagerProtocol


    init(commandFactory: WalletCommandFactoryProtocol,
         localizationManager: LocalizationManagerProtocol,
         address: String) {
        self.commandFactory = commandFactory
        self.localizationManager = localizationManager
        self.address = address
    }
}

extension CopyAssetAddressCommand: WalletCommandDecoratorProtocol {
    func execute() throws {
        let locale = localizationManager.selectedLocale

        let alertView = UIAlertController(title: address,
                                          message: nil,
                                          preferredStyle: .actionSheet)

        let copyTitle = R.string.localizable.commonCopy(preferredLanguages: locale.rLanguages)
        let copyAction = UIAlertAction(title: copyTitle, style: .default) { [weak self] _ in
            UIPasteboard.general.string = self?.address
            let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages))
            try? self?.commandFactory.preparePresentationCommand(for: success).execute()
        }

        alertView.addAction(copyAction)

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
        alertView.addAction(cancelAction)

        try commandFactory.preparePresentationCommand(for: alertView).execute()
    }
}
