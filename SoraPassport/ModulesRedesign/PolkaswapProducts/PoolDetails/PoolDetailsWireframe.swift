import Foundation
import UIKit
import SoraUIKit
import CommonWallet
import RobinHood

protocol PoolDetailsWireframeProtocol: AlertPresentable {
    func showLiquidity(on controller: UIViewController?,
                       poolInfo: PoolInfo,
                       stakedPools: [StakedPool],
                       type: Liquidity.TransactionLiquidityType,
                       assetManager: AssetManagerProtocol,
                       poolsService: PoolsServiceInputProtocol?,
                       fiatService: FiatServiceProtocol?,
                       providerFactory: BalanceProviderFactory,
                       operationFactory: WalletNetworkOperationFactoryProtocol,
                       assetsProvider: AssetProviderProtocol?,
                       completionHandler: (() -> Void)?)
}

final class PoolDetailsWireframe: PoolDetailsWireframeProtocol {
    
    func showLiquidity(
        on controller: UIViewController?,
        poolInfo: PoolInfo,
        stakedPools: [StakedPool],
        type: Liquidity.TransactionLiquidityType,
        assetManager: AssetManagerProtocol,
        poolsService: PoolsServiceInputProtocol?,
        fiatService: FiatServiceProtocol?,
        providerFactory: BalanceProviderFactory,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol?,
        completionHandler: (() -> Void)?) {
            guard let fiatService = fiatService,
                  let poolsService = poolsService else { return }
            
            guard let assetDetailsController = type == .add ? LiquidityViewFactory.createView(poolInfo: poolInfo,
                                                                                              assetManager: assetManager,
                                                                                              fiatService: fiatService,
                                                                                              poolsService: poolsService,
                                                                                              operationFactory: operationFactory,
                                                                                              assetsProvider: assetsProvider)
                    :
                        LiquidityViewFactory.createRemoveLiquidityView(poolInfo: poolInfo,
                                                                       stakedPools: stakedPools,
                                                                       assetManager: assetManager,
                                                                       fiatService: fiatService,
                                                                       poolsService: poolsService,
                                                                       providerFactory: providerFactory,
                                                                       operationFactory: operationFactory,
                                                                       assetsProvider: assetsProvider,
                                                                       completionHandler: completionHandler) else { return }
            
            
            
            let containerView = BlurViewController()
            containerView.modalPresentationStyle = .overFullScreen
            
            let navigationController = UINavigationController(rootViewController: assetDetailsController)
            navigationController.navigationBar.backgroundColor = .clear
            navigationController.addCustomTransitioning()
            
            containerView.add(navigationController)
            
            controller?.present(containerView, animated: true)
        }
}
