// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit
import SoraKeystore
import SoraFoundation
import Then
import SoraUIKit
import IrohaCrypto
import SSFUtils

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static let walletIndex: Int = 0
    
    @MainActor
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
        
        let primitiveFactory = WalletPrimitiveFactory(keystore: Keychain())
        
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return nil
        }
        
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        assetManager.setup(for: SelectedWalletSettings.shared)

        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let accountSettings = try? primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager) else {
            return nil
        }
        
        let farmingService = DemeterFarmingService(
            operationFactory: DemeterFarmingOperationFactory(engine: connection),
            fiatService: FiatService.shared,
            assetManager: assetManager
        )
        
        guard let walletContext = try? WalletContextFactory().createContext(connection: connection, 
                                                                            assetManager: assetManager,
                                                                            accountSettings: accountSettings, 
                                                                            demeterFarmingService: farmingService) else {
            return nil
        }
        
        let feeProvider = FeeProvider()
        
        guard let viewControllers = redesignedViewControllers(for: view,
                                                              walletContext: walletContext,
                                                              assetManager: assetManager,
                                                              accountSettings: accountSettings, 
                                                              feeProvider: feeProvider,
                                                              farmingService: farmingService) else {
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
        
        let primitiveFactory = WalletPrimitiveFactory(keystore: Keychain())
        
        guard
            let selectedAccount = SelectedWalletSettings.shared.currentAccount,
            let accountSettings = try? primitiveFactory.createAccountSettings(for: selectedAccount, assetManager: assetManager),
            let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return
        }
        
        let farmingService = DemeterFarmingService(
            operationFactory: DemeterFarmingOperationFactory(engine: connection),
            fiatService: FiatService.shared,
            assetManager: assetManager
        )
        
        guard let walletContext = try? WalletContextFactory().createContext(connection: connection,
                                                                            assetManager: assetManager,
                                                                            accountSettings: accountSettings,
                                                                            demeterFarmingService: farmingService) else {
            return
        }
        
        let assetInfos = assetManager.getAssetList() ?? []
        let providerFactory = BalanceProviderFactory(accountId: accountSettings.accountId,
                                                     cacheFacade: CoreDataCacheFacade.shared,
                                                     networkOperationFactory: walletContext.networkOperationFactory,
                                                     identifierFactory: SingleProviderIdentifierFactory())
        
        let assetsProvider = AssetProvider(assetInfos: assetInfos, providerFactory: providerFactory)
        
        let assetViewModelsFactory = AssetViewModelFactory(walletAssets: assetInfos,
                                            assetManager: assetManager,
                                            fiatService: FiatService.shared)
        
        let assetsViewModelService = AssetsItemService(marketCapService: MarketCapService.shared,
                                                       fiatService: FiatService.shared,
                                                       assetViewModelsFactory: assetViewModelsFactory,
                                                       assetManager: assetManager,
                                                       assetProvider: assetsProvider)
        assetsProvider.add(observer: assetsViewModelService)
        
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        
        let poolsService = AccountPoolsService(operationManager: OperationManagerFacade.sharedManager,
                                              networkFacade: walletContext.networkOperationFactory,
                                              polkaswapNetworkFacade: polkaswapContext,
                                              config: ApplicationConfig.shared)
        farmingService.poolsService = poolsService
        
        let poolViewModelsfactory = PoolViewModelFactory(walletAssets: assetInfos,
                                            assetManager: assetManager,
                                           fiatService: FiatService.shared)
        
        let poolsViewModelService = PoolsItemService(marketCapService: MarketCapService.shared,
                                           fiatService: FiatService.shared,
                                           poolViewModelsFactory: poolViewModelsfactory)
        poolsService.appendDelegate(delegate: poolsViewModelService)
        
        let editViewService = EditViewService(poolsService: poolsService)
        poolsService.appendDelegate(delegate: editViewService)
        
        let feeProvider = FeeProvider()
        
        guard let walletController = createWalletRedesignController(walletContext: walletContext,
                                                                    assetManager: assetManager,
                                                                    poolsService: poolsService,
                                                                    assetsProvider: assetsProvider,
                                                                    poolsViewModelService: poolsViewModelService,
                                                                    assetsViewModelService: assetsViewModelService,
                                                                    editViewService: editViewService,
                                                                    accountSettings: accountSettings, 
                                                                    farmingService: farmingService,
                                                                    feeProvider: feeProvider,
                                                                    localizationManager: localizationManager) else {
            return
        }
        
        wireframe.walletContext = walletContext
        view.didReplaceView(for: walletController, for: Self.walletIndex)
    }
    
    @MainActor
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

//MARK: Redesign

extension MainTabBarViewFactory {
    @MainActor
    private static func redesignedViewControllers(for view: MainTabBarViewController,
                                                  walletContext: CommonWalletContextProtocol,
                                                  assetManager: AssetManagerProtocol,
                                                  accountSettings: WalletAccountSettingsProtocol,
                                                  feeProvider: FeeProviderProtocol,
                                                  farmingService: DemeterFarmingService) -> [UIViewController]? {
        
        let providerFactory = BalanceProviderFactory(accountId: accountSettings.accountId,
                                                     cacheFacade: CoreDataCacheFacade.shared,
                                                     networkOperationFactory: walletContext.networkOperationFactory,
                                                     identifierFactory: SingleProviderIdentifierFactory())
        
        
        let assetInfos = assetManager.getAssetList() ?? []
        let assetsProvider = AssetProvider(assetInfos: assetInfos, providerFactory: providerFactory)
        
        let assetViewModelsFactory = AssetViewModelFactory(walletAssets: assetInfos,
                                            assetManager: assetManager,
                                            fiatService: FiatService.shared)
        
        let assetsViewModelService = AssetsItemService(marketCapService: MarketCapService.shared,
                                                       fiatService: FiatService.shared,
                                                       assetViewModelsFactory: assetViewModelsFactory,
                                                       assetManager: assetManager,
                                                       assetProvider: assetsProvider)
        assetsProvider.add(observer: assetsViewModelService)
        
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return nil
        }
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        
        let poolsService = AccountPoolsService(operationManager: OperationManagerFacade.sharedManager,
                                              networkFacade: walletContext.networkOperationFactory,
                                              polkaswapNetworkFacade: polkaswapContext,
                                              config: ApplicationConfig.shared)
        farmingService.poolsService = poolsService
        let factory = PoolViewModelFactory(walletAssets: assetInfos,
                                            assetManager: assetManager,
                                           fiatService: FiatService.shared)
        
        let poolsViewModelService = PoolsItemService(marketCapService: MarketCapService.shared,
                                           fiatService: FiatService.shared,
                                           poolViewModelsFactory: factory)

        poolsService.appendDelegate(delegate: poolsViewModelService)
        
        let editViewService = EditViewService(poolsService: poolsService)
        poolsService.appendDelegate(delegate: editViewService)
        
        guard let walletController = createWalletRedesignController(walletContext: walletContext,
                                                                    assetManager: assetManager,
                                                                    poolsService: poolsService,
                                                                    assetsProvider: assetsProvider,
                                                                    poolsViewModelService: poolsViewModelService,
                                                                    assetsViewModelService: assetsViewModelService,
                                                                    editViewService: editViewService,
                                                                    accountSettings: accountSettings, 
                                                                    farmingService: farmingService, 
                                                                    feeProvider: feeProvider) else {
            return nil
        }
        
        guard let settingsController = createMoreMenuController(walletContext: walletContext,
                                                                assetsProvider: assetsProvider,
                                                                accountSettings: accountSettings) else {
            return nil
        }
        
        guard let activityController = createActivityController(with: assetManager, assetInfos: assetInfos) else {
            return nil
        }
        
        guard let investController = createInvestController(walletContext: walletContext,
                                                            assetManager: assetManager,
                                                            networkFacade: walletContext.networkOperationFactory,
                                                            polkaswapNetworkFacade: polkaswapContext,
                                                            poolsService: poolsService,
                                                            accountSettings: accountSettings,
                                                            assetsProvider: assetsProvider, 
                                                            farmingService: farmingService,
                                                            feeProvider: feeProvider,
                                                            walletAssets: assetInfos) else {
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
                                               poolsViewModelService: PoolsItemService,
                                               assetsViewModelService: AssetsItemService,
                                               editViewService: EditViewServiceProtocol,
                                               accountSettings: WalletAccountSettingsProtocol,
                                               farmingService: DemeterFarmingServiceProtocol,
                                               feeProvider: FeeProviderProtocol,
                                               localizationManager: LocalizationManagerProtocol = LocalizationManager.shared) -> UIViewController? {
        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()) else {
            return nil
        }
        
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
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
        Task {
            await APYService.shared.setup(factory: polkaswapContext)
        }
        
        let referralFactory = ReferralsOperationFactory(settings: SettingsManager.shared,
                                                        keychain: Keychain(),
                                                        engine: connection,
                                                        runtimeRegistry: runtimeRegistry,
                                                        selectedAccount: selectedAccount)
        
        let marketCapService = MarketCapService.shared

        let walletController = RedesignWalletViewFactory.createView(providerFactory: providerFactory,
                                                                    assetManager: assetManager,
                                                                    fiatService: FiatService.shared,
                                                                    farmingService: farmingService,
                                                                    networkFacade: walletContext.networkOperationFactory,
                                                                    accountId: accountSettings.accountId,
                                                                    address: selectedAccount.address,
                                                                    polkaswapNetworkFacade: polkaswapContext,
                                                                    qrEncoder: qrEncoder,
                                                                    sharingFactory: shareFactory,
                                                                    poolsService: poolsService,
                                                                    referralFactory: referralFactory,
                                                                    assetsProvider: assetsProvider,
                                                                    walletContext: walletContext,
                                                                    poolsViewModelService: poolsViewModelService,
                                                                    assetsViewModelService: assetsViewModelService,
                                                                    marketCapService: marketCapService,
                                                                    editViewService: editViewService, 
                                                                    feeProvider: feeProvider)
        
        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.walletTitle(preferredLanguages: locale.rLanguages)
        }
        
        let image = R.image.tabBar.wallet()
        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        
        let navigationController = SoraNavigationController().then {
            $0.navigationBar.isHidden = true
            $0.tabBarItem = createTabBarItem(title: currentTitle, image: image)
            $0.viewControllers = [walletController]
        }
        
        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }
        
        return navigationController
    }
    
    static func createMoreMenuController(
        for localizationManager: LocalizationManagerProtocol = LocalizationManager.shared,
        walletContext: CommonWalletContextProtocol,
        assetsProvider: AssetProviderProtocol,
        accountSettings: WalletAccountSettingsProtocol
    ) -> UIViewController? {
        
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount else {
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
        assetInfos: [AssetInfo],
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared) -> UIViewController? {
            guard let view = ActivityViewFactory.createView(assetManager: assetManager, aseetList: assetInfos) else {
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
                                       poolsService: PoolsServiceInputProtocol,
                                       accountSettings: WalletAccountSettingsProtocol,
                                       assetsProvider: AssetProviderProtocol,
                                       farmingService: DemeterFarmingServiceProtocol,
                                       feeProvider: FeeProviderProtocol,
                                       walletAssets: [AssetInfo]) -> UINavigationController? {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()) else {
            return nil
        }
        
        let qrEncoder = WalletQREncoder(networkType: selectedAccount.networkType,
                                        publicKey: selectedAccount.publicKeyData,
                                        username: selectedAccount.username)
        
        let marketCapService = MarketCapService.shared
        let fiatService = FiatService.shared
        let itemFactory = ExploreItemFactory(assetManager: assetManager)
        
        let factory = AssetViewModelFactory(walletAssets: walletAssets,
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        let explorePoolsService = ExplorePoolsService(assetInfos: walletAssets,
                                                      fiatService: fiatService,
                                                      polkaswapOperationFactory: polkaswapNetworkFacade,
                                                      networkFacade: networkFacade)
        
        let poolViewModelsService = ExplorePoolsViewModelService(itemFactory: itemFactory,
                                                                poolsService: explorePoolsService,
                                                                apyService: APYService.shared)
        
        let poolFactory = PoolViewModelFactory(walletAssets: walletAssets,
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
                                         marketCapService: marketCapService,
                                         explorePoolsService: explorePoolsService,
                                         apyService: APYService.shared,
                                         assetViewModelFactory: factory,
                                         poolsService: poolsService,
                                         poolViewModelsFactory: poolFactory,
                                         providerFactory: providerFactory,
                                         networkFacade: networkFacade,
                                         accountId: accountId,
                                         address: selectedAccount.address,
                                         polkaswapNetworkFacade: polkaswapNetworkFacade,
                                         qrEncoder: qrEncoder,
                                         sharingFactory: shareFactory,
                                         referralFactory: referralFactory,
                                         assetsProvider: assetsProvider,
                                         farmingService: farmingService, 
                                         poolViewModelsService: poolViewModelsService, 
                                         feeProvider: feeProvider, 
                                         walletService: WalletService(operationFactory: walletContext.networkOperationFactory))
        
        let assetViewModelsService = ExploreAssetViewModelService(marketCapService: marketCapService,
                                                                  fiatService: fiatService,
                                                                  itemFactory: itemFactory,
                                                                  assetInfos: walletAssets)
        
        let assetsPageViewModel = ExploreAssetsPageViewModel(wireframe: wireframe,
                                                             assetViewModelsService: assetViewModelsService)
        
        let poolsPageViewModel = ExplorePoolsPageViewModel(wireframe: wireframe,
                                                           poolViewModelsService: poolViewModelsService,
                                                           accountPoolsService: poolsService)
        
        let farmsViewModelsService = ExploreFarmsViewModelService(demeterFarmingService: farmingService)
        
        let farmsPageViewModel = ExploreFarmsPageViewModel(wireframe: wireframe,
                                                           farmsViewModelsService: farmsViewModelsService,
                                                           accountPoolsService: poolsService)
        
        let searchViewModel = ExploreSearchPageViewModel(wireframe: wireframe,
                                                         assetViewModelsService: assetViewModelsService,
                                                         poolViewModelsService: poolViewModelsService,
                                                         farmsViewModelsService: farmsViewModelsService)
        
        let title = R.string.localizable.commonExplore(preferredLanguages: .currentLocale)
        
        let view = ExploreViewController(
            viewModels: [assetsPageViewModel, poolsPageViewModel, farmsPageViewModel],
            searchViewModel: searchViewModel
        )
        view.wireframe = wireframe
        view.localizationManager = LocalizationManager.shared
        
        assetsPageViewModel.view = view
        poolsPageViewModel.view = view
        farmsPageViewModel.view = view
        searchViewModel.view = view
        
        let navigationController = SoraNavigationController().then {
            $0.navigationBar.topItem?.title = title
            $0.navigationBar.layoutMargins.left = 16
            $0.navigationBar.layoutMargins.right = 16
            $0.tabBarItem = createTabBarItem(title: title, image: R.image.wallet.globe())
            $0.viewControllers = [view]
        }
        return navigationController
    }
    
    @MainActor
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
        
        let marketCapService = MarketCapService.shared
        
        guard let swapController = SwapViewFactory.createView(selectedTokenId: WalletAssetId.xor.rawValue,
                                                              selectedSecondTokenId: "",
                                                              assetManager: assetManager,
                                                              fiatService: FiatService.shared,
                                                              networkFacade: walletContext.networkOperationFactory,
                                                              polkaswapNetworkFacade: polkaswapContext,
                                                              assetsProvider: assetsProvider,
                                                              marketCapService: marketCapService) else { return nil }
        
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
        
        let normalAttributes = [NSAttributedString.Key.foregroundColor: SoramitsuUI.shared.theme.palette.color(.fgSecondary),
                                NSAttributedString.Key.font: FontType.textBoldXS.font]
        let selectedAttributes = [NSAttributedString.Key.foregroundColor: SoramitsuUI.shared.theme.palette.color(.accentPrimary),
                                  NSAttributedString.Key.font: FontType.textBoldXS.font]
        
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
