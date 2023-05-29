import Foundation
import RobinHood
import CommonWallet

protocol PoolDetailsViewFactoryProtocol: AnyObject {
    static func createView(poolInfo: PoolInfo,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           providerFactory: BalanceProviderFactory,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?,
                           dismissHandler: (() -> Void)?) -> PoolDetailsViewController?
}

final class PoolDetailsViewFactory: PoolDetailsViewFactoryProtocol {
    static func createView(poolInfo: PoolInfo,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           providerFactory: BalanceProviderFactory,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?,
                           dismissHandler: (() -> Void)?) -> PoolDetailsViewController? {
        let viewModel = PoolDetailsViewModel(wireframe: PoolDetailsWireframe(),
                                             poolInfo: poolInfo,
                                             fiatService: fiatService,
                                             poolsService: poolsService,
                                             assetManager: assetManager,
                                             detailsFactory: DetailViewModelFactory(assetManager: assetManager),
                                             providerFactory: providerFactory,
                                             operationFactory: operationFactory,
                                             assetsProvider: assetsProvider)
        viewModel.dismissHandler = dismissHandler

        let view = PoolDetailsViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}



