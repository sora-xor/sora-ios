import Foundation
import CommonWallet
import SoraFoundation

enum AssetSelectionMode {
    case send
    case receive
}

final class SelectAssetCommand: WalletCommandDecoratorProtocol {
    var undelyingCommand: WalletCommandProtocol?

    let commandFactory: WalletCommandFactoryProtocol
    let assets: [WalletAsset]
    let mode: AssetSelectionMode
    let localizationManager: LocalizationManagerProtocol

    init(commandFactory: WalletCommandFactoryProtocol,
         assets: [WalletAsset],
         mode: AssetSelectionMode,
         localizationManager: LocalizationManagerProtocol) {
        self.commandFactory = commandFactory
        self.assets = assets
        self.mode = mode
        self.localizationManager = localizationManager
    }

    func execute() throws {
        let viewController = ModalPickerFactory.createPickerForAssetList(self.assets,
                                                                         selectedType: nil,
                                                                         delegate: self,
                                                                         context: nil)
        viewController?.navigationItem.largeTitleDisplayMode = .never
        let languages = localizationManager.selectedLocale.rLanguages
        viewController?.title = R.string.localizable.commonChooseAsset(preferredLanguages: languages)
      
        let presentationCommand = commandFactory.preparePresentationCommand(for: viewController!)
        presentationCommand.presentationStyle = .modal(inNavigation: true)

        try presentationCommand.execute()
    }
}

extension SelectAssetCommand: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        let selected = self.assets[index]
        let command: WalletCommandProtocol
        switch mode {
        case .send:
            command = commandFactory.prepareSendCommand(for: selected.identifier)
        case .receive:
            command = commandFactory.prepareReceiveCommand(for: selected.identifier)
        }

        self.undelyingCommand = command
        try? command.execute()
    }

}
