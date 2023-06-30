import Foundation
import SoraUIKit
import RobinHood
import CommonWallet
import SoraFoundation
import SCard

protocol RedesignWalletWireframeProtocol: AlertPresentable {
    func showFullListAssets(on controller: UIViewController?,
                            assetManager: AssetManagerProtocol,
                            fiatService: FiatServiceProtocol,
                            assetViewModelFactory: AssetViewModelFactoryProtocol,
                            providerFactory: BalanceProviderFactory,
                            poolService: PoolsServiceInputProtocol,
                            networkFacade: WalletNetworkOperationFactoryProtocol?,
                            accountId: String,
                            address: String,
                            polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                            qrEncoder: WalletQREncoderProtocol,
                            sharingFactory: AccountShareFactoryProtocol,
                            referralFactory: ReferralsOperationFactoryProtocol,
                            assetsProvider: AssetProviderProtocol,
                            updateHandler: (() -> Void)?)
    
    func showFullListPools(on controller: UIViewController?,
                           poolService: PoolsServiceInputProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolViewModelFactory: PoolViewModelFactoryProtocol,
                           providerFactory: BalanceProviderFactory,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol)
    
    func showAssetDetails(on viewController: UIViewController?,
                          assetInfo: AssetInfo,
                          assetManager: AssetManagerProtocol,
                          fiatService: FiatServiceProtocol,
                          assetViewModelFactory: AssetViewModelFactoryProtocol,
                          poolsService: PoolsServiceInputProtocol,
                          poolViewModelsFactory: PoolViewModelFactoryProtocol,
                          providerFactory: BalanceProviderFactory,
                          networkFacade: WalletNetworkOperationFactoryProtocol?,
                          accountId: String,
                          address: String,
                          polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                          qrEncoder: WalletQREncoderProtocol,
                          sharingFactory: AccountShareFactoryProtocol,
                          referralFactory: ReferralsOperationFactoryProtocol,
                          assetsProvider: AssetProviderProtocol)
    
    func showPoolDetails(on viewController: UIViewController?,
                         poolInfo: PoolInfo,
                         assetManager: AssetManagerProtocol,
                         fiatService: FiatServiceProtocol,
                         poolsService: PoolsServiceInputProtocol,
                         providerFactory: BalanceProviderFactory,
                         operationFactory: WalletNetworkOperationFactoryProtocol,
                         assetsProvider: AssetProviderProtocol)

    func showSoraCard(on viewController: UIViewController?,
                      address: AccountAddress,
                      balanceProvider: RobinHood.SingleValueProvider<[CommonWallet.BalanceData]>?)
    
    func showManageAccount(on view: UIViewController, completion: @escaping () -> Void)
    
    func showScanQR(on view: UIViewController,
                    networkFacade: WalletNetworkOperationFactoryProtocol,
                    assetManager: AssetManagerProtocol,
                    qrEncoder: WalletQREncoderProtocol,
                    sharingFactory: AccountShareFactoryProtocol,
                    assetsProvider: AssetProviderProtocol?,
                    completion: @escaping (ScanQRResult) -> Void)
    
    func showSend(on controller: UIViewController?,
                  selectedTokenId: String?,
                  selectedAddress: String,
                  fiatService: FiatServiceProtocol?,
                  assetManager: AssetManagerProtocol?,
                  providerFactory: BalanceProviderFactory,
                  networkFacade: WalletNetworkOperationFactoryProtocol?,
                  assetsProvider: AssetProviderProtocol,
                  qrEncoder: WalletQREncoderProtocol,
                  sharingFactory: AccountShareFactoryProtocol)
    
    func showConfirmSendingAsset(on controller: UIViewController?,
                                 assetId: String,
                                 walletService: WalletServiceProtocol,
                                 assetManager: AssetManagerProtocol,
                                 fiatService: FiatServiceProtocol,
                                 recipientAddress: String,
                                 firstAssetAmount: Decimal,
                                 fee: Decimal,
                                 assetsProvider: AssetProviderProtocol?)
    
    func showReferralProgram(from view: MoreMenuViewProtocol?,
                             walletContext: CommonWalletContextProtocol)
}

final class RedesignWalletWireframe: RedesignWalletWireframeProtocol {

    func showSoraCard(
        on viewController: UIViewController?,
        address: AccountAddress,
        balanceProvider: SingleValueProvider<[BalanceData]>?
    ) {
        guard let viewController else { return }

        // initSoraCard(address: address, balanceProvider: balanceProvider)

        SCard.shared?.start(in: viewController)
    }

    func showFullListAssets(on controller: UIViewController?,
                            assetManager: AssetManagerProtocol,
                            fiatService: FiatServiceProtocol,
                            assetViewModelFactory: AssetViewModelFactoryProtocol,
                            providerFactory: BalanceProviderFactory,
                            poolService: PoolsServiceInputProtocol,
                            networkFacade: WalletNetworkOperationFactoryProtocol?,
                            accountId: String,
                            address: String,
                            polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                            qrEncoder: WalletQREncoderProtocol,
                            sharingFactory: AccountShareFactoryProtocol,
                            referralFactory: ReferralsOperationFactoryProtocol,
                            assetsProvider: AssetProviderProtocol,
                            updateHandler: (() -> Void)?) {
        let viewModel = ManageAssetListViewModel(assetViewModelFactory: assetViewModelFactory,
                                                 fiatService: fiatService,
                                                 assetManager: assetManager,
                                                 providerFactory: providerFactory,
                                                 poolService: poolService,
                                                 networkFacade: networkFacade,
                                                 accountId: accountId,
                                                 address: address,
                                                 polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                 qrEncoder: qrEncoder,
                                                 sharingFactory: sharingFactory,
                                                 referralFactory: referralFactory,
                                                 assetsProvider: assetsProvider,
                                                 updateHandler: updateHandler)
        
        let assetListController = ProductListViewController(viewModel: viewModel)
        viewModel.view = assetListController
                
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        let newNav = SoraNavigationController(rootViewController: assetListController)
        newNav.navigationBar.backgroundColor = .clear
        newNav.addCustomTransitioning()
        
        containerView.add(newNav)
        controller?.present(containerView, animated: true)
    }
    
    func showFullListPools(on controller: UIViewController?,
                           poolService: PoolsServiceInputProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolViewModelFactory: PoolViewModelFactoryProtocol,
                           providerFactory: BalanceProviderFactory,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol) {
        let viewModel = PoolListViewModel(poolsService: poolService,
                                          assetManager: assetManager,
                                          fiatService: fiatService,
                                          poolViewModelFactory: poolViewModelFactory,
                                          providerFactory: providerFactory,
                                          operationFactory: operationFactory,
                                          assetsProvider: assetsProvider)
        
        poolService.appendDelegate(delegate: viewModel)
        
        let assetListController = ProductListViewController(viewModel: viewModel)
        viewModel.view = assetListController
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        let navigationController = UINavigationController(rootViewController: assetListController)
        navigationController.modalPresentationStyle = .fullScreen
        
        containerView.add(navigationController)
        controller?.present(containerView, animated: true)
    }
    
    func showAssetDetails(on viewController: UIViewController?,
                          assetInfo: AssetInfo,
                          assetManager: AssetManagerProtocol,
                          fiatService: FiatServiceProtocol,
                          assetViewModelFactory: AssetViewModelFactoryProtocol,
                          poolsService: PoolsServiceInputProtocol,
                          poolViewModelsFactory: PoolViewModelFactoryProtocol,
                          providerFactory: BalanceProviderFactory,
                          networkFacade: WalletNetworkOperationFactoryProtocol?,
                          accountId: String,
                          address: String,
                          polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                          qrEncoder: WalletQREncoderProtocol,
                          sharingFactory: AccountShareFactoryProtocol,
                          referralFactory: ReferralsOperationFactoryProtocol,
                          assetsProvider: AssetProviderProtocol) {
        guard let assetDetailsController = AssetDetailsViewFactory.createView(assetInfo: assetInfo,
                                                                              assetManager: assetManager,
                                                                              fiatService: fiatService,
                                                                              assetViewModelFactory: assetViewModelFactory,
                                                                              poolsService: poolsService,
                                                                              poolViewModelsFactory: poolViewModelsFactory,
                                                                              providerFactory: providerFactory,
                                                                              networkFacade: networkFacade,
                                                                              accountId: accountId,
                                                                              address: address,
                                                                              polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                                              qrEncoder: qrEncoder,
                                                                              sharingFactory: sharingFactory,
                                                                              referralFactory: referralFactory,
                                                                              assetsProvider: assetsProvider) else {
            return
        }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(assetDetailsController)
        
        viewController?.present(containerView, animated: true)
    }
    
    func showPoolDetails(on viewController: UIViewController?,
                         poolInfo: PoolInfo,
                         assetManager: AssetManagerProtocol,
                         fiatService: FiatServiceProtocol,
                         poolsService: PoolsServiceInputProtocol,
                         providerFactory: BalanceProviderFactory,
                         operationFactory: WalletNetworkOperationFactoryProtocol,
                         assetsProvider: AssetProviderProtocol) {
        guard let assetDetailsController = PoolDetailsViewFactory.createView(poolInfo: poolInfo,
                                                                             assetManager: assetManager,
                                                                             fiatService: fiatService,
                                                                             poolsService: poolsService,
                                                                             providerFactory: providerFactory,
                                                                             operationFactory: operationFactory,
                                                                             assetsProvider: assetsProvider,
                                                                             dismissHandler: nil) else {
            return
        }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let assetDetailNavigationController = UINavigationController(rootViewController: assetDetailsController)
        assetDetailNavigationController.navigationBar.backgroundColor = .clear
        assetDetailNavigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
        assetDetailNavigationController.addCustomTransitioning()
        
        containerView.add(assetDetailNavigationController)
        
        viewController?.present(containerView, animated: true)
    }
    
    func showManageAccount(on view: UIViewController, completion: @escaping () -> Void) {
        guard let changeAccountView = ChangeAccountViewFactory.changeAccountViewController(with: completion) else {
            return
        }
            
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        let newNav = SoraNavigationController(rootViewController: changeAccountView.controller)
        newNav.navigationBar.backgroundColor = .clear
        newNav.addCustomTransitioning()
        
        containerView.add(newNav)
        view.present(containerView, animated: true)
    }
    
    func showScanQR(on view: UIViewController,
                    networkFacade: WalletNetworkOperationFactoryProtocol,
                    assetManager: AssetManagerProtocol,
                    qrEncoder: WalletQREncoderProtocol,
                    sharingFactory: AccountShareFactoryProtocol,
                    assetsProvider: AssetProviderProtocol?,
                    completion: @escaping (ScanQRResult) -> Void) {
        guard let currentUser = SelectedWalletSettings.shared.currentAccount else { return }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let scanView = ScanQRViewFactory.createView(assetManager: assetManager,
                                                    currentUser: currentUser,
                                                    networkFacade: networkFacade,
                                                    qrEncoder: qrEncoder,
                                                    sharingFactory: sharingFactory,
                                                    assetsProvider: assetsProvider,
                                                    completion: completion)
        containerView.add(scanView.controller)
        view.present(containerView, animated: true)
    }
    
    func showSend(on controller: UIViewController?,
                  selectedTokenId: String?,
                  selectedAddress: String,
                  fiatService: FiatServiceProtocol?,
                  assetManager: AssetManagerProtocol?,
                  providerFactory: BalanceProviderFactory,
                  networkFacade: WalletNetworkOperationFactoryProtocol?,
                  assetsProvider: AssetProviderProtocol,
                  qrEncoder: WalletQREncoderProtocol,
                  sharingFactory: AccountShareFactoryProtocol) {
        let viewModel = InputAssetAmountViewModel(selectedTokenId: selectedTokenId,
                                                  selectedAddress: selectedAddress,
                                                  fiatService: fiatService,
                                                  assetManager: assetManager,
                                                  providerFactory: providerFactory,
                                                  networkFacade: networkFacade,
                                                  wireframe: InputAssetAmountWireframe(),
                                                  assetsProvider: assetsProvider,
                                                  qrEncoder: qrEncoder,
                                                  sharingFactory: sharingFactory)
        let inputAmountController = InputAssetAmountViewController(viewModel: viewModel)
        viewModel.view = inputAmountController
        
        let navigationController = UINavigationController(rootViewController: inputAmountController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
    
    
    func showConfirmSendingAsset(on controller: UIViewController?,
                                 assetId: String,
                                 walletService: WalletServiceProtocol,
                                 assetManager: AssetManagerProtocol,
                                 fiatService: FiatServiceProtocol,
                                 recipientAddress: String,
                                 firstAssetAmount: Decimal,
                                 fee: Decimal,
                                 assetsProvider: AssetProviderProtocol?) {
        let viewModel = ConfirmSendingViewModel(wireframe: ConfirmWireframe(),
                                                fiatService: fiatService,
                                                assetManager: assetManager,
                                                detailsFactory: DetailViewModelFactory(assetManager: assetManager),
                                                assetId: assetId,
                                                recipientAddress: recipientAddress,
                                                firstAssetAmount: firstAssetAmount,
                                                transactionType: .outgoing,
                                                fee: fee,
                                                walletService: walletService,
                                                assetsProvider: assetsProvider)
        let view = ConfirmViewController(viewModel: viewModel)
        viewModel.view = view
        
        let navigationController = UINavigationController(rootViewController: view)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
    
    func showReferralProgram(from view: MoreMenuViewProtocol?,
                             walletContext: CommonWalletContextProtocol) {
        guard let friendsView = FriendsViewFactory.createTestView(walletContext: walletContext) else {
            return
        }
        if let navigationController = view?.controller.navigationController {
            let containerView = BlurViewController()
            containerView.modalPresentationStyle = .overFullScreen

            let newNav = SoraNavigationController(rootViewController: friendsView.controller)
            newNav.navigationBar.backgroundColor = .clear
            newNav.addCustomTransitioning()
            containerView.add(newNav)
            navigationController.present(containerView, animated: true)
        }
    }
}
