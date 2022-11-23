import Foundation
import CommonWallet
import SoraFoundation

enum AssetSelectionMode {
    case send
    case receive
    case manage
}

final class SelectAssetCommand: WalletCommandDecoratorProtocol {
    var undelyingCommand: WalletCommandProtocol?

    let commandFactory: WalletCommandFactoryProtocol
    let assets: [WalletAsset]
    let mode: AssetSelectionMode
    let localizationManager: LocalizationManagerProtocol
    let assetManager: AssetManagerProtocol

    init(commandFactory: WalletCommandFactoryProtocol,
         assets: [WalletAsset],
         assetManager: AssetManagerProtocol,
         mode: AssetSelectionMode,
         localizationManager: LocalizationManagerProtocol) {
        self.commandFactory = commandFactory
        self.assets = assets
        self.mode = mode
        self.localizationManager = localizationManager
        self.assetManager = assetManager
    }

    func execute() throws {
        let assetList = assetManager.sortedAssets(self.assets, onlyVisible: true).filter {$0.modes.contains(.all)}
        //TODO: remove filter after capital hack resolved
        let viewController = ModalPickerFactory.createPickerForAssetList(assetList,
                                                                         selectedType: nil,
                                                                         delegate: self,
                                                                         context: assetManager)
        let languages = localizationManager.selectedLocale.rLanguages
        let title: String
        switch mode {
        case .send:
            title = R.string.localizable.selectAssetSend(preferredLanguages: languages)
        case .receive:
            title = R.string.localizable.selectAssetReceive(preferredLanguages: languages)
        default:
            title = R.string.localizable.commonChooseAsset(preferredLanguages: languages)
        }
        viewController?.title = title

        let presentationCommand = commandFactory.preparePresentationCommand(for: viewController!)
        presentationCommand.presentationStyle = .modal(inNavigation: true)

        try presentationCommand.execute()
    }
}

extension SelectAssetCommand: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        let assetList = assetManager.sortedAssets(self.assets, onlyVisible: true)
        let selected = assetList[index]
        let command: WalletCommandProtocol
        switch mode {
        case .send:
            command = commandFactory.prepareSendCommand(for: selected.identifier)
        case .receive:
            command = commandFactory.prepareReceiveCommand(for: selected.identifier)
        case .manage:
            command = SendToContactCommand(nextAction: {
                //stub, no selection in this mode
            })
        }

        self.undelyingCommand = command
        try? command.execute()
    }
}

final class ManageAssetsCommand: WalletCommandDecoratorProtocol {
    var undelyingCommand: WalletCommandProtocol?

    let commandFactory: WalletCommandFactoryProtocol
    let assets: [WalletAsset]
    let mode: AssetSelectionMode
    let localizationManager: LocalizationManagerProtocol
    let assetManager: AssetManagerProtocol
    var batchChanges: [AssetInfo] = []

    init(commandFactory: WalletCommandFactoryProtocol,
         assets: [WalletAsset],
         assetManager: AssetManagerProtocol,
         mode: AssetSelectionMode,
         localizationManager: LocalizationManagerProtocol) {
        self.commandFactory = commandFactory
        self.assets = assets
        self.mode = mode
        self.localizationManager = localizationManager
        self.assetManager = assetManager
    }

    func execute() throws {
        guard let info = assetManager.getAssetList() else { return }
        batchChanges = info
        let assetList = assetManager.sortedAssets(self.assets, onlyVisible: false)
        let viewController = ModalPickerFactory.createPickerForAssetList(assetList,
                                                                         selectedType: nil,
                                                                         delegate: self,
                                                                         context: assetManager)
        viewController?.navigationItem.largeTitleDisplayMode = .never
        let languages = localizationManager.selectedLocale.rLanguages
        viewController?.title = R.string.localizable.commonChooseAsset(preferredLanguages: languages)
        viewController?.isEditing = true

        let presentationCommand = commandFactory.preparePresentationCommand(for: viewController!)
        presentationCommand.presentationStyle = .modal(inNavigation: true)

        try presentationCommand.execute()
    }
}

extension ManageAssetsCommand: ModalPickerViewControllerDelegate {

    func modalPickerDone(context: AnyObject?) {
        assetManager.updateAssetList(batchChanges)
        try? commandFactory.prepareAccountUpdateCommand().execute()
     }

    func modalPickerDidMoveItem(from: Int, to index: Int) {
        let item = batchChanges.remove(at: from)
        batchChanges.insert(item, at: index)
    }

    func modalPickerDidToggle(itemIndex: Int) {
        var item = batchChanges.remove(at: itemIndex)
        item.visible = !item.visible
        batchChanges.insert(item, at: itemIndex)
    }

}
