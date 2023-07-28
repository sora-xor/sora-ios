import Foundation
import SoraUIKit
import CommonWallet

protocol ExploreWireframeProtocol {
    func showAssetList(on viewController: UIViewController?, viewModelService: ExploreAssetViewModelService)
    func showPoolList(on viewController: UIViewController?, viewModelService: ExplorePoolViewModelService)
    func showAssetDetails(on viewController: UIViewController?, assetId: String)
    func showAccountPoolDetails(on viewController: UIViewController?, poolInfo: PoolInfo)
}

final class ExploreWireframe: ExploreWireframeProtocol {
    
    weak var fiatService: FiatServiceProtocol?
    let itemFactory: ExploreItemFactory
    let assetManager: AssetManagerProtocol
    let marketCapService: MarketCapServiceProtocol
    let poolService: ExplorePoolsServiceInputProtocol
    let apyService: APYServiceProtocol?
    let assetViewModelFactory: AssetViewModelFactoryProtocol
    let poolsService: PoolsServiceInputProtocol
    let poolViewModelsFactory: PoolViewModelFactoryProtocol
    let providerFactory: BalanceProviderFactory
    let networkFacade: WalletNetworkOperationFactoryProtocol?
    let accountId: String
    let address: String
    let polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?
    let qrEncoder: WalletQREncoderProtocol
    let sharingFactory: AccountShareFactoryProtocol
    let referralFactory: ReferralsOperationFactoryProtocol
    let assetsProvider: AssetProviderProtocol

    init(
        fiatService: FiatServiceProtocol?,
        itemFactory: ExploreItemFactory,
        assetManager: AssetManagerProtocol,
        marketCapService: MarketCapServiceProtocol,
        poolService: ExplorePoolsServiceInputProtocol,
        apyService: APYServiceProtocol?,
        assetViewModelFactory: AssetViewModelFactoryProtocol,
        poolsService: PoolsServiceInputProtocol,
        poolViewModelsFactory: PoolViewModelFactoryProtocol,
        providerFactory: BalanceProviderFactory,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        accountId: String,
        address: String,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
        qrEncoder: WalletQREncoderProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        referralFactory: ReferralsOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol
    ) {
        
        self.fiatService = fiatService
        self.itemFactory = itemFactory
        self.assetManager = assetManager
        self.marketCapService = marketCapService
        self.poolService = poolService
        self.apyService = apyService
        self.assetViewModelFactory = assetViewModelFactory
        self.poolsService = poolsService
        self.poolViewModelsFactory = poolViewModelsFactory
        self.providerFactory = providerFactory
        self.networkFacade = networkFacade
        self.accountId = accountId
        self.address = address
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.qrEncoder = qrEncoder
        self.sharingFactory = sharingFactory
        self.referralFactory = referralFactory
        self.assetsProvider = assetsProvider
    }
    
    func showAssetList(on viewController: UIViewController?, viewModelService: ExploreAssetViewModelService) {
        let viewModel = ViewAssetListViewModel(viewModelService: viewModelService, wireframe: self)
        
        let assetListController = ProductListViewController(viewModel: viewModel)
        viewModel.view = assetListController
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        let newNav = SoraNavigationController(rootViewController: assetListController)
        newNav.navigationBar.backgroundColor = .clear
        newNav.addCustomTransitioning()
        
        containerView.add(newNav)
        viewController?.present(containerView, animated: true)
    }
    
    func showPoolList(on viewController: UIViewController?, viewModelService: ExplorePoolViewModelService) {
        let viewModel = ViewPoolListViewModel(viewModelService: viewModelService, wireframe: self, accountPoolsService: poolsService)
        
        let assetListController = ProductListViewController(viewModel: viewModel)
        viewModel.view = assetListController
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        let newNav = SoraNavigationController(rootViewController: assetListController)
        newNav.navigationBar.backgroundColor = .clear
        newNav.addCustomTransitioning()
        
        containerView.add(newNav)
        viewController?.present(containerView, animated: true)
    }
    
    func showAssetDetails(on viewController: UIViewController?, assetId: String) {
        guard let assetInfo = assetManager.assetInfo(for: assetId),
              let fiatService = fiatService,
              let polkaswapNetworkFacade = polkaswapNetworkFacade,
              let assetDetailsController = AssetDetailsViewFactory.createView(assetInfo: assetInfo,
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
    
    func showAccountPoolDetails(on viewController: UIViewController?, poolInfo: PoolInfo) {
        guard let fiatService = fiatService,
              let networkFacade = networkFacade,
              let assetDetailsController = PoolDetailsViewFactory.createView(poolInfo: poolInfo,
                                                                             assetManager: assetManager,
                                                                             fiatService: fiatService,
                                                                             poolsService: poolsService,
                                                                             providerFactory: providerFactory,
                                                                             operationFactory: networkFacade,
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
}
