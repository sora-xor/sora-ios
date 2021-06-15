import Foundation
import CoreData
import CommonWallet
import RobinHood
import SoraFoundation

final class WalletCommandDecoratorFactory: WalletCommandDecoratorFactoryProtocol {

    let localizationManager: LocalizationManagerProtocol
    let assets: [WalletAsset]
    let address: String

    init(localizationManager: LocalizationManagerProtocol,
         assets: [WalletAsset],
         address: String) {
        self.localizationManager = localizationManager
        self.assets = assets
        self.address = address
    }

    func createAssetDetailsDecorator(with commandFactory: WalletCommandFactoryProtocol,
                                     asset: WalletAsset,
                                     balanceData: BalanceData?) -> WalletCommandDecoratorProtocol? {
            return CopyAssetAddressCommand(commandFactory: commandFactory, localizationManager: localizationManager, address: address)

    }

    func createSendCommandDecorator(with commandFactory: WalletCommandFactoryProtocol) -> WalletCommandDecoratorProtocol? {
        let selectCommand = SelectAssetCommand(commandFactory: commandFactory,
                                               assets: assets,
                                               mode: .send,
                                               localizationManager: localizationManager)

        return selectCommand
    }

    func createReceiveCommandDecorator(with commandFactory: WalletCommandFactoryProtocol) -> WalletCommandDecoratorProtocol? {
        let selectCommand = SelectAssetCommand(commandFactory: commandFactory,
                                               assets: assets,
                                               mode: .receive,
                                               localizationManager: localizationManager)

        return selectCommand
    }
}
