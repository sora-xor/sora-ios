import Foundation
import UIKit
import SoraUIKit
import CommonWallet
import RobinHood

protocol DiscoveryWireframeProtocol: AlertPresentable {
    func showLiquidity(on controller: UIViewController?,
                       assetManager: AssetManagerProtocol,
                       poolsService: PoolsServiceInputProtocol?,
                       fiatService: FiatServiceProtocol?,
                       operationFactory: WalletNetworkOperationFactoryProtocol,
                       assetsProvider: AssetProviderProtocol)
}

final class DiscoveryWireframe: DiscoveryWireframeProtocol {
    
    func showLiquidity(
        on controller: UIViewController?,
        assetManager: AssetManagerProtocol,
        poolsService: PoolsServiceInputProtocol?,
        fiatService: FiatServiceProtocol?,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol) {
            guard let fiatService = fiatService,
                  let poolsService = poolsService else { return }
            
            guard let assetDetailsController = LiquidityViewFactory.createView(poolInfo: nil,
                                                                               assetManager: assetManager,
                                                                               fiatService: fiatService,
                                                                               poolsService: poolsService,
                                                                               operationFactory: operationFactory,
                                                                               assetsProvider: assetsProvider) else { return }
            
            let containerView = BlurViewController()
            containerView.modalPresentationStyle = .overFullScreen
            
            let navigationController = UINavigationController(rootViewController: assetDetailsController)
            navigationController.navigationBar.backgroundColor = .clear
            navigationController.addCustomTransitioning()
            
            containerView.add(navigationController)
            
            controller?.present(containerView, animated: true)
        }
}
