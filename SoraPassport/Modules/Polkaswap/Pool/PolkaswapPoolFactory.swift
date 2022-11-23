import CommonWallet
import UIKit

final class PolkaswapPoolFactory: PolkaswapPoolFactoryProtocol {
    static func createView(networkFacade: WalletNetworkOperationFactoryProtocol, polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol, assets: [AssetInfo], commandFactory: WalletCommandFactoryProtocol) -> PolkaswapPoolViewProtocol {

        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        let presenter = PolkaswapPoolPresenter(assetManager: assetManager,
                                               networkFacade: networkFacade,
                                               polkaswapNetworkFacade: polkaswapNetworkFacade,
                                               assets: assets,
                                               commandFactory: commandFactory)
        let view = PolkaswapPoolViewController()
        presenter.view = view
        let interactor = PolkaswapPoolInteractor(operationManager: OperationManagerFacade.sharedManager,
                                                 networkFacade: networkFacade,
                                                 polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                 config: ApplicationConfig.shared)
        interactor.presenter = presenter
        presenter.interactor = interactor
        view.presenter = presenter
        return view
    }
}
