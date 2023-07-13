import Foundation
import RobinHood
import CommonWallet

protocol LiquidityViewFactoryProtocol: AnyObject {
    static func createView(poolInfo: PoolInfo?,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?) -> PolkaswapViewController?
    
    static func createRemoveLiquidityView(poolInfo: PoolInfo,
                                          assetManager: AssetManagerProtocol,
                                          fiatService: FiatServiceProtocol,
                                          poolsService: PoolsServiceInputProtocol,
                                          providerFactory: BalanceProviderFactory,
                                          operationFactory: WalletNetworkOperationFactoryProtocol,
                                          assetsProvider: AssetProviderProtocol?,
                                          completionHandler: (() -> Void)?) -> PolkaswapViewController?
}

final class LiquidityViewFactory: LiquidityViewFactoryProtocol {
    static func createView(poolInfo: PoolInfo?,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?) -> PolkaswapViewController? {
        let viewModel = SupplyLiquidityViewModel(
            wireframe: LiquidityWireframe(),
            poolInfo: poolInfo,
            fiatService: fiatService,
            apyService: APYService.shared,
            poolsService: poolsService,
            assetManager: assetManager,
            detailsFactory: DetailViewModelFactory(assetManager: assetManager),
            operationFactory: operationFactory,
            assetsProvider: assetsProvider)
        
        let view = PolkaswapViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
    
    static func createRemoveLiquidityView(poolInfo: PoolInfo,
                                          assetManager: AssetManagerProtocol,
                                          fiatService: FiatServiceProtocol,
                                          poolsService: PoolsServiceInputProtocol,
                                          providerFactory: BalanceProviderFactory,
                                          operationFactory: WalletNetworkOperationFactoryProtocol,
                                          assetsProvider: AssetProviderProtocol?,
                                          completionHandler: (() -> Void)?) -> PolkaswapViewController? {
        guard let engine = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else { return nil }
        let farmingService = DemeterFarmingService(operationFactory: DemeterFarmingOperationFactory(engine: engine))
        let viewModel = RemoveLiquidityViewModel(
            wireframe: LiquidityWireframe(),
            poolInfo: poolInfo,
            apyService: APYService.shared,
            fiatService: fiatService,
            poolsService: poolsService,
            assetManager: assetManager,
            detailsFactory: DetailViewModelFactory(assetManager: assetManager),
            providerFactory: providerFactory,
            operationFactory: operationFactory,
            assetsProvider: assetsProvider,
            farmingService: farmingService)
        viewModel.completionHandler = completionHandler
        
        let view = PolkaswapViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}



