import UIKit
import SoraKeystore
import CommonWallet
import SoraFoundation
import Then
import SoraUIKit
import IrohaCrypto

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static let walletIndex: Int = 0
    
    static func createView() -> MainTabBarViewProtocol? {
        
        guard let keystoreImportService: KeystoreImportServiceProtocol = URLHandlingService.shared.findService() else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }
        
        let interactor = MainTabBarInteractor(eventCenter: EventCenter.shared,
                                              serviceCoordinator: ServiceCoordinator.shared,
                                              keystoreImportService: keystoreImportService)
        
        let view = MainTabBarViewController()
        view.localizationManager = LocalizationManager.shared
        
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return nil
        }
        
        guard let walletContext = try? WalletContextFactory().createContext(connection: connection) else {
            return nil
        }
        
        guard let viewControllers = redesignedViewControllers(for: view, walletContext: walletContext) else {
            return nil
        }
        
        view.viewControllers = viewControllers
        
        let presenter = MainTabBarPresenter()
        
        let wireframe = MainTabBarWireframe(walletContext: walletContext)
        
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        
        return view
    }
    
    static func reloadWalletView(on view: MainTabBarViewProtocol,
                                 wireframe: MainTabBarWireframeProtocol) {
        let localizationManager = LocalizationManager.shared
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        assetManager.setup(for: SelectedWalletSettings.shared)
        
        guard
            let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()),
            let walletContext = try? WalletContextFactory().createContext(connection: connection) else {
            return
        }
        
        let primitiveFactory = WalletPrimitiveFactory(keystore: Keychain())
        
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let accountSettings = try? primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager) else {
            return
        }
        
        let providerFactory = BalanceProviderFactory(accountId: accountSettings.accountId,
                                                     cacheFacade: CoreDataCacheFacade.shared,
                                                     networkOperationFactory: walletContext.networkOperationFactory,
                                                     identifierFactory: SingleProviderIdentifierFactory())
        
        let assetsProvider = AssetProvider(assetManager: assetManager, providerFactory: providerFactory)
        
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        
        let poolService = AccountPoolsService(operationManager: OperationManagerFacade.sharedManager,
                                              networkFacade: walletContext.networkOperationFactory,
                                              polkaswapNetworkFacade: polkaswapContext,
                                              config: ApplicationConfig.shared)
        
        
        guard let walletController = createWalletRedesignController(walletContext: walletContext,
                                                                    assetManager: assetManager,
                                                                    poolsService: poolService,
                                                                    assetsProvider: assetsProvider,
                                                                    localizationManager: localizationManager) else {
            return
        }
        
        wireframe.walletContext = walletContext
        view.didReplaceView(for: walletController, for: Self.walletIndex)
    }
    
    static func swapDisclamerController(completion: (() -> Void)?) -> UIViewController? {
        let viewModel = SwapDisclaimerViewModel()
        viewModel.completion = completion
        
        let disclamerView = SwapDisclaimerViewController(viewModel: viewModel)
        viewModel.view = disclamerView
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(disclamerView)
        
        return containerView
    }
    
}

//MARK: Old design

extension MainTabBarViewFactory {
    
    static func createWalletController(
        walletContext: CommonWalletContextProtocol,
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared
    ) -> UIViewController? {
        guard let walletController = try? walletContext.createRootController() else {
            return nil
        }
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonAssets(preferredLanguages: locale.rLanguages)
        }
        
        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        
        walletController.navigationItem.largeTitleDisplayMode = .never
        walletController.tabBarItem = createTabBarItem(title: currentTitle, image: R.image.tabBar.wallet())
        
        localizationManager.addObserver(with: walletController) { [weak walletController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            walletController?.tabBarItem.title = currentTitle
        }
        
        return walletController
    }
}

//MARK: Redesign

extension MainTabBarViewFactory {
    private static func redesignedViewControllers(for view: MainTabBarViewController,
                                                  walletContext: CommonWalletContextProtocol) -> [UIViewController]? {
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        
        let primitiveFactory = WalletPrimitiveFactory(keystore: Keychain())
        
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let accountSettings = try? primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager) else {
            return nil
        }
        
        let providerFactory = BalanceProviderFactory(accountId: accountSettings.accountId,
                                                     cacheFacade: CoreDataCacheFacade.shared,
                                                     networkOperationFactory: walletContext.networkOperationFactory,
                                                     identifierFactory: SingleProviderIdentifierFactory())
        
        let assetsProvider = AssetProvider(assetManager: assetManager, providerFactory: providerFactory)
        
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return nil
        }
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        
        let poolService = AccountPoolsService(operationManager: OperationManagerFacade.sharedManager,
                                              networkFacade: walletContext.networkOperationFactory,
                                              polkaswapNetworkFacade: polkaswapContext,
                                              config: ApplicationConfig.shared)
        
        guard let walletController = createWalletRedesignController(walletContext: walletContext,
                                                                    assetManager: assetManager,
                                                                    poolsService: poolService,
                                                                    assetsProvider: assetsProvider) else {
            return nil
        }
        
        guard let settingsController = createMoreMenuController(walletContext: walletContext, assetsProvider: assetsProvider) else {
            return nil
        }
        
        guard let activityController = createActivityController(with: assetManager) else {
            return nil
        }
        
        guard let investController = createInvestController(walletContext: walletContext,
                                                            assetManager: assetManager,
                                                            networkFacade: walletContext.networkOperationFactory,
                                                            polkaswapNetworkFacade: polkaswapContext,
                                                            assetsProvider: assetsProvider) else {
            return nil
        }
        
        view.middleButtonHadler = {
            guard let swapViewController = createSwapController(walletContext: walletContext,
                                                                assetManager: assetManager,
                                                                assetsProvider: assetsProvider,
                                                                localizationManager: LocalizationManager.shared) else { return }
            guard let containerView = swapDisclamerController(completion: {
                UserDefaults.standard.set(true, forKey: "isDisclamerShown")
                view.present(swapViewController, animated: true)
            }) else { return }
            
            if ApplicationConfig.shared.isDisclamerShown {
                view.present(swapViewController, animated: true)
            } else {
                view.present(containerView, animated: true)
            }
        }
        
        let fakeSwapViewController = UIViewController()
        fakeSwapViewController.tabBarItem.isEnabled = false
        
        return  [walletController, investController, fakeSwapViewController, activityController, settingsController]
    }
    
    static func createWalletRedesignController(walletContext: CommonWalletContextProtocol,
                                               assetManager: AssetManagerProtocol,
                                               poolsService: PoolsServiceInputProtocol,
                                               assetsProvider: AssetProviderProtocol,
                                               localizationManager: LocalizationManagerProtocol = LocalizationManager.shared) -> UIViewController? {
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
              let walletContext = try? WalletContextFactory().createContext(connection: connection) else {
            return nil
        }
        
        let primitiveFactory = WalletPrimitiveFactory(keystore: Keychain())
        
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let accountSettings = try? primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager) else {
            return nil
        }
        
        let qrEncoder = WalletQREncoder(networkType: selectedAccount.networkType,
                                        publicKey: selectedAccount.publicKeyData,
                                        username: selectedAccount.username)
        
        let shareFactory = AccountShareFactory(address: selectedAccount.address,
                                               assets: accountSettings.assets,
                                               localizationManager: localizationManager)
        
        let providerFactory = BalanceProviderFactory(accountId: accountSettings.accountId,
                                                     cacheFacade: CoreDataCacheFacade.shared,
                                                     networkOperationFactory: walletContext.networkOperationFactory,
                                                     identifierFactory: SingleProviderIdentifierFactory())
        
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        
        APYService.shared.polkaswapNetworkOperationFactory = polkaswapContext
        
        let referralFactory = ReferralsOperationFactory(settings: SettingsManager.shared,
                                                        keychain: Keychain(),
                                                        engine: connection,
                                                        runtimeRegistry: runtimeRegistry,
                                                        selectedAccount: selectedAccount)
        
        let walletController = RedesignWalletViewFactory.createView(providerFactory: providerFactory,
                                                                    assetManager: assetManager,
                                                                    fiatService: FiatService.shared,
                                                                    networkFacade: walletContext.networkOperationFactory,
                                                                    accountId: accountSettings.accountId,
                                                                    address: selectedAccount.address,
                                                                    polkaswapNetworkFacade: polkaswapContext,
                                                                    qrEncoder: qrEncoder,
                                                                    sharingFactory: shareFactory,
                                                                    poolsService: poolsService,
                                                                    referralFactory: referralFactory,
                                                                    assetsProvider: assetsProvider,
                                                                    walletContext: walletContext)
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonAssets(preferredLanguages: locale.rLanguages)
        }
        
        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        
        walletController.navigationItem.largeTitleDisplayMode = .never
        walletController.tabBarItem = createTabBarItem(title: currentTitle, image: R.image.tabBar.wallet())
        
        localizationManager.addObserver(with: walletController) { [weak walletController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            walletController?.tabBarItem.title = currentTitle
        }
        
        return walletController
    }
    
    static func createMoreMenuController(
        for localizationManager: LocalizationManagerProtocol = LocalizationManager.shared,
        walletContext: CommonWalletContextProtocol,
        assetsProvider: AssetProviderProtocol
    ) -> UIViewController? {
        
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        
        let primitiveFactory = WalletPrimitiveFactory(keystore: Keychain())
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let accountSettings = try? primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager)
        else {
            return nil
        }
        
        let balanceFactory = BalanceProviderFactory(
            accountId: accountSettings.accountId,
            cacheFacade: CoreDataCacheFacade.shared,
            networkOperationFactory: walletContext.networkOperationFactory,
            identifierFactory: SingleProviderIdentifierFactory()
        )
        
        guard let view = MoreMenuViewFactory.createView(
            walletContext: walletContext,
            fiatService: FiatService.shared,
            balanceFactory: balanceFactory,
            address: selectedAccount.address,
            assetsProvider: assetsProvider,
            assetManager: assetManager
        ) else {
            return nil
        }
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonSettings(preferredLanguages: locale.rLanguages)
        }
        
        let currentTitle = R.string.localizable.commonMore(preferredLanguages: .currentLocale)
        
        let image = R.image.wallet.more()
        
        let navigationController = SoraNavigationController().then {
            $0.navigationBar.topItem?.title = currentTitle
            $0.navigationBar.layoutMargins.left = 16
            $0.navigationBar.layoutMargins.right = 16
            $0.navigationBar.prefersLargeTitles = true
            $0.tabBarItem = createTabBarItem(title: currentTitle, image: image)
            $0.viewControllers = [view.controller]
        }
        
        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }
        
        return navigationController
    }
    
    static func createActivityController(
        with assetManager: AssetManagerProtocol,
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared) -> UIViewController? {
            guard let view = ActivityViewFactory.createView(assetManager: assetManager) else {
                return nil
            }
            
            let title = R.string.localizable.commonActivity(preferredLanguages: .currentLocale)
            
            let navigationController = SoraNavigationController().then {
                $0.navigationBar.topItem?.title = title
                $0.navigationBar.prefersLargeTitles = true
                $0.navigationBar.layoutMargins.left = 16
                $0.navigationBar.layoutMargins.right = 16
                $0.tabBarItem = createTabBarItem(title: title, image: R.image.wallet.activity())
                $0.viewControllers = [view]
            }
            
            let localizableTitle = LocalizableResource { locale in
                R.string.localizable.commonActivity(preferredLanguages: locale.rLanguages)
            }
            
            localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
                let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
                navigationController?.tabBarItem.title = currentTitle
            }
            
            return navigationController
        }
    
    static func createInvestController(walletContext: CommonWalletContextProtocol,
                                       assetManager: AssetManagerProtocol,
                                       networkFacade: WalletNetworkOperationFactoryProtocol?,
                                       polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
                                       assetsProvider: AssetProviderProtocol) -> UINavigationController? {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
              let accountSettings = try? WalletPrimitiveFactory(keystore: Keychain()).createAccountSettings(for: selectedAccount,
                                                                                                            assetManager: assetManager) else {
            return nil
        }
        
        let qrEncoder = WalletQREncoder(networkType: selectedAccount.networkType,
                                        publicKey: selectedAccount.publicKeyData,
                                        username: selectedAccount.username)
        
        let marketCap = MarketCapService(assetManager: assetManager)
        let fiatService = FiatService.shared
        let itemFactory = ExploreItemFactory(assetManager: assetManager)
        let assetViewModelsService = ExploreAssetViewModelService(marketCapService: marketCap,
                                                                  fiatService: fiatService,
                                                                  itemFactory: itemFactory,
                                                                  assetManager: assetManager)
        
        let factory = AssetViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        let explorePoolsService = ExplorePoolsService(assetManager: assetManager,
                                                      fiatService: fiatService,
                                                      polkaswapOperationFactory: polkaswapNetworkFacade,
                                                      networkFacade: networkFacade)
        
        let accountPoolsService = AccountPoolsService(operationManager: OperationManagerFacade.sharedManager,
                                                      networkFacade: walletContext.networkOperationFactory,
                                                      polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                      config: ApplicationConfig.shared)
        
        let poolViewModelsService = ExplorePoolViewModelService(itemFactory: itemFactory,
                                                                poolService: explorePoolsService,
                                                                apyService: APYService.shared)
        
        let poolFactory = PoolViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                               assetManager: assetManager,
                                               fiatService: fiatService)
        
        let providerFactory = BalanceProviderFactory(accountId: accountSettings.accountId,
                                                     cacheFacade: CoreDataCacheFacade.shared,
                                                     networkOperationFactory: walletContext.networkOperationFactory,
                                                     identifierFactory: SingleProviderIdentifierFactory())
        
        let shareFactory = AccountShareFactory(address: selectedAccount.address,
                                               assets: accountSettings.assets,
                                               localizationManager: LocalizationManager.shared)
        
        let referralFactory = ReferralsOperationFactory(settings: SettingsManager.shared,
                                                        keychain: Keychain(),
                                                        engine: connection,
                                                        runtimeRegistry: runtimeRegistry,
                                                        selectedAccount: selectedAccount)
        let accountId = (try? SS58AddressFactory().accountId(
            fromAddress: selectedAccount.address,
            type: selectedAccount.networkType
        ).toHex(includePrefix: true)) ?? ""
        
        let wireframe = ExploreWireframe(fiatService: fiatService,
                                         itemFactory: itemFactory,
                                         assetManager: assetManager,
                                         marketCapService: marketCap,
                                         poolService: explorePoolsService,
                                         apyService: APYService.shared,
                                         assetViewModelFactory: factory,
                                         poolsService: accountPoolsService,
                                         poolViewModelsFactory: poolFactory,
                                         providerFactory: providerFactory,
                                         networkFacade: networkFacade,
                                         accountId: accountId,
                                         address: selectedAccount.address,
                                         polkaswapNetworkFacade: polkaswapNetworkFacade,
                                         qrEncoder: qrEncoder,
                                         sharingFactory: shareFactory,
                                         referralFactory: referralFactory,
                                         assetsProvider: assetsProvider)
        
        
        let viewModel = ExploreViewModel(wireframe: wireframe,
                                         accountPoolsService: accountPoolsService,
                                         assetViewModelsService: assetViewModelsService,
                                         poolViewModelsService: poolViewModelsService)
        
        let title = R.string.localizable.commonExplore(preferredLanguages: .currentLocale)
        
        let view = ExploreViewController()
        view.viewModel = viewModel
        view.localizationManager = LocalizationManager.shared
        viewModel.view = view
        
        let navigationController = SoraNavigationController().then {
            $0.navigationBar.topItem?.title = title
            $0.navigationBar.prefersLargeTitles = true
            $0.navigationBar.layoutMargins.left = 16
            $0.navigationBar.layoutMargins.right = 16
            $0.tabBarItem = createTabBarItem(title: title, image: R.image.wallet.globe())
            $0.viewControllers = [view]
        }
        return navigationController
    }
    
    static func createSwapController(
        walletContext: CommonWalletContextProtocol,
        assetManager: AssetManagerProtocol,
        assetsProvider: AssetProviderProtocol,
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared
    ) -> UIViewController? {
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return nil
        }
        
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        
        guard let swapController = SwapViewFactory.createView(selectedTokenId: WalletAssetId.xor.rawValue,
                                                              selectedSecondTokenId: "",
                                                              assetManager: assetManager,
                                                              fiatService: FiatService.shared,
                                                              networkFacade: walletContext.networkOperationFactory,
                                                              polkaswapNetworkFacade: polkaswapContext,
                                                              assetsProvider: assetsProvider) else { return nil }
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonAssets(preferredLanguages: locale.rLanguages)
        }
        
        localizationManager.addObserver(with: swapController) { [weak swapController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            swapController?.tabBarItem.title = currentTitle
        }
        
        return swapController
    }
}

private extension MainTabBarViewFactory {
    
    static func createTabBarItem(title: String, image: UIImage?, selectedImage: UIImage? = nil) -> UITabBarItem {
        
        let tabBarItem = UITabBarItem(title: title, image: image, selectedImage: selectedImage)
        
        // Style is set here for compatibility reasons for iOS 12.x and less.
        // For iOS 13 styling see MainTabBarViewController's 'configure' method.
        
        if #available(iOS 13.0, *) {
            return tabBarItem
        }
        
        let normalAttributes = [NSAttributedString.Key.foregroundColor: R.color.baseContentTertiary()!]
        let selectedAttributes = [NSAttributedString.Key.foregroundColor: R.color.neumorphism.tint()]
        
        tabBarItem.setTitleTextAttributes(normalAttributes, for: .normal)
        tabBarItem.setTitleTextAttributes(selectedAttributes, for: .selected)
        
        return tabBarItem
    }
}

private extension MainTabBarViewFactory {
    
    static func createNetworkStatusPresenter(localizationManager: LocalizationManagerProtocol = LocalizationManager.shared)
    -> NetworkAvailabilityLayerInteractorOutputProtocol? {
        guard let window = UIApplication.shared.keyWindow as? ApplicationStatusPresentable else {
            return nil
        }
        
        let prenseter = NetworkAvailabilityLayerPresenter()
        prenseter.localizationManager = localizationManager
        prenseter.view = window
        
        return prenseter
    }
}
