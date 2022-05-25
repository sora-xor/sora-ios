import CommonWallet
import UIKit

final class PolkaswapPoolFactory: PolkaswapPoolFactoryProtocol {
    static func createView(networkFacade: WalletNetworkOperationFactoryProtocol, assetList: [WalletAsset], commandFactory: WalletCommandFactoryProtocol) -> PolkaswapPoolViewProtocol {
    #if F_RELEASE || F_TEST
        return PolkaswapPoolPlaceholderView()
    #else
        let presenter = PolkaswapPoolPresenter(assetManager: AssetManager.shared, networkFacade: networkFacade, assets: assetList, commandFactory: commandFactory)
        let view = PolkaswapPoolViewController()
        presenter.view = view
        view.presenter = presenter
        return view
    #endif
    }
}
