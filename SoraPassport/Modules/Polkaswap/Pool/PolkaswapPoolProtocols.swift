import CommonWallet
import SoraFoundation

protocol PolkaswapPoolFactoryProtocol: AnyObject {
    static func createView(networkFacade: WalletNetworkOperationFactoryProtocol, assetList: [WalletAsset], commandFactory: WalletCommandFactoryProtocol) -> PolkaswapPoolViewProtocol
}

protocol PolkaswapPoolViewProtocol: ControllerBackedProtocol & Localizable {
    func setPoolList(_ pools: [PoolDetails])
}
