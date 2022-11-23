import Foundation
import CoreData
import CommonWallet
import RobinHood
import SoraFoundation

final class WalletCommandDecoratorFactory: WalletCommandDecoratorFactoryProtocol {

    let localizationManager: LocalizationManagerProtocol
    let assets: [WalletAsset]
    let assetManager: AssetManagerProtocol
    let address: String

    init(localizationManager: LocalizationManagerProtocol,
         assets: [WalletAsset],
         assetManager: AssetManagerProtocol,
         address: String) {
        self.localizationManager = localizationManager
        self.assets = assets
        self.address = address
        self.assetManager = assetManager
    }

    func createAssetDetailsDecorator(with commandFactory: WalletCommandFactoryProtocol,
                                     asset: WalletAsset,
                                     balanceData: BalanceData?) -> WalletCommandDecoratorProtocol? {
            return CopyAssetAddressCommand(commandFactory: commandFactory, localizationManager: localizationManager, address: address)

    }

    func createScanCommandDecorator(with commandFactory: WalletCommandFactoryProtocol) -> WalletPresentationCommandProtocol? {
        let command = commandFactory.prepareScanReceiverCommand()
        command.presentationStyle = .modal(inNavigation: true)
        return command
    }

    func createSendCommandDecorator(with commandFactory: WalletCommandFactoryProtocol) -> WalletCommandDecoratorProtocol? {
        let selectCommand = SelectAssetCommand(commandFactory: commandFactory,
                                               assets: assets,
                                               assetManager: assetManager,
                                               mode: .send,
                                               localizationManager: localizationManager)

        return selectCommand
    }

    func createReceiveCommandDecorator(with commandFactory: WalletCommandFactoryProtocol) -> WalletCommandDecoratorProtocol? {
        let selectCommand = SelectAssetCommand(commandFactory: commandFactory,
                                               assets: assets,
                                               assetManager: assetManager,
                                               mode: .receive,
                                               localizationManager: localizationManager)

        return selectCommand
    }

    func createTransferConfirmationDecorator(with commandFactory: WalletCommandFactoryProtocol,
                                             payload: ConfirmationPayload)
        -> WalletPresentationCommandProtocol? {
            let command = commandFactory.prepareConfirmation(with: payload)
            command.presentationStyle = .modal(inNavigation: true)
            return command
    }

    func createVisibilityToggleCommand(with commandFactory: WalletCommandFactoryProtocol, for asset: WalletAsset) -> WalletCommandDecoratorProtocol? {
        return ToggleAssetCommand(asset: asset, assetManager: assetManager, commandFactory: commandFactory)
    }

    func createManageCommandDecorator(with commandFactory: WalletCommandFactoryProtocol) -> WalletCommandDecoratorProtocol? {

        let manageCommand = ManageAssetsCommand(commandFactory: commandFactory,
                                               assets: assets,
                                               assetManager: assetManager,
                                               mode: .manage,
                                               localizationManager: localizationManager)
        return manageCommand
    }
}

final class ToggleAssetCommand: WalletCommandDecoratorProtocol {
    var undelyingCommand: WalletCommandProtocol?

    let commandFactory: WalletCommandFactoryProtocol
    let asset: WalletAsset
    let assetManager: AssetManagerProtocol

    init(asset: WalletAsset,
         assetManager: AssetManagerProtocol,
         commandFactory: WalletCommandFactoryProtocol) {
        self.asset = asset
        self.assetManager = assetManager
        self.commandFactory = commandFactory
    }

    func execute() throws {
        if var info = assetManager.getAssetList(),
           let itemIndex = info.firstIndex { (assetInfo) -> Bool in
               assetInfo.assetId == asset.identifier
           } {

            var item = info.remove(at: itemIndex)
            item.visible = !item.visible
            info.insert(item, at: itemIndex)
            assetManager.updateAssetList(info)
            try? commandFactory.prepareAccountUpdateCommand().execute()
        }
    }
}
