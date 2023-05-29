import Foundation
import RobinHood
import CommonWallet
import SoraUIKit
import UIKit

protocol SwapViewFactoryProtocol: AnyObject {
    static func createView(
        selectedTokenId: String,
        selectedSecondTokenId: String,
        assetManager: AssetManagerProtocol,
        fiatService: FiatServiceProtocol,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
        assetsProvider: AssetProviderProtocol?) -> UIViewController?
}

final class SwapViewFactory: SwapViewFactoryProtocol {
    static func createView(
        selectedTokenId: String,
        selectedSecondTokenId: String,
        assetManager: AssetManagerProtocol,
        fiatService: FiatServiceProtocol,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
        assetsProvider: AssetProviderProtocol?) -> UIViewController? {
        let interactor = PolkaswapMainInteractor(operationManager: OperationManager(),
                                                 eventCenter: EventCenter.shared)
        interactor.polkaswapNetworkFacade = polkaswapNetworkFacade
        let viewModel = SwapViewModel(
            selectedTokenId: selectedTokenId,
            selectedSecondTokenId: selectedSecondTokenId,
            wireframe: LiquidityWireframe(),
            fiatService: fiatService,
            assetManager: assetManager,
            detailsFactory: DetailViewModelFactory(assetManager: assetManager),
            eventCenter: EventCenter.shared,
            interactor: interactor,
            networkFacade: networkFacade,
            assetsProvider: assetsProvider,
            lpServiceFee: LPFeeService(),
            polkaswapNetworkFacade: polkaswapNetworkFacade)
        
        interactor.presenter = viewModel
        
        let view = PolkaswapViewController(viewModel: viewModel)
        viewModel.view = view
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let navigationController = UINavigationController(rootViewController: view)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        containerView.add(navigationController)
        
        return containerView
    }
}



