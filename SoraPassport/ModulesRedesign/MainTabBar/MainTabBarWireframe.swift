// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

import SoraFoundation
import SoraUIKit
import SoraKeystore

final class MainTabBarWireframe: MainTabBarWireframeProtocol {
    var walletContext: CommonWalletContextProtocol

    init(walletContext: CommonWalletContextProtocol) {
        self.walletContext = walletContext
    }

    func showNewWalletView(on view: MainTabBarViewProtocol?) {
        if let view = view {
            MainTabBarViewFactory.reloadWalletView(on: view, wireframe: self)
        }
    }

    func reloadWalletContent() {
        try? walletContext.prepareAccountUpdateCommand().execute()
    }

    func removeClaim(on view: MainTabBarViewProtocol?) {
        guard let tabBarController = view?.controller else {
            return
        }

        tabBarController.dismiss(animated: true) { [weak self] in
            self?.showNewWalletView(on: view)
        }
    }

    @MainActor func presentClaim(on view: MainTabBarViewProtocol?, with service: MigrationServiceProtocol) {
        guard let tabBarController = view?.controller else {
            return
        }

        guard canPresentImport(on: tabBarController) else {
            return
        }

        guard let migrationController = MigrationViewFactory.createViewRedesign(with: service)?.controller else {
            return
        }

        let containerView = BlurViewController()
        containerView.isClosable = false
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(migrationController)
        
        let presentingController = tabBarController.topModalViewController
        presentingController.present(containerView, animated: true, completion: nil)
    }

    func presentAccountImport(on view: MainTabBarViewProtocol?) {
        guard let tabBarController = view?.controller else {
            return
        }

        guard canPresentImport(on: tabBarController) else {
            return
        }

        guard let importController = AccountImportViewFactory
            .createViewForAdding(endAddingBlock: nil)?.controller else {
            return
        }

        let navigationController = SoraNavigationController(rootViewController: importController)

        let presentingController = tabBarController.topModalViewController
        presentingController.present(navigationController, animated: true, completion: nil)
    }

    func showTransactionSuccess(on view: MainTabBarViewProtocol?) {
        if let view = view {
            let title = R.string.localizable.walletTransactionSubmitted(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
            let alert = ModalAlertFactory.createSuccessAlert(title)
            view.controller.present(alert, animated: true, completion: nil)
        }
    }
    
    @MainActor
    func recreateWalletViewController(on view: MainTabBarViewProtocol?) {
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
        
        let factory = PoolViewModelFactory(walletAssets: assetInfos,
                                            assetManager: assetManager,
                                           fiatService: FiatService.shared)
        
        let poolsViewModelService = PoolsItemService(marketCapService: MarketCapService.shared,
                                           fiatService: FiatService.shared,
                                           poolViewModelsFactory: factory)
        poolsService.appendDelegate(delegate: poolsViewModelService)
        
        let editViewService = EditViewService(poolsService: poolsService)
        poolsService.appendDelegate(delegate: editViewService)

        let feeProvider = FeeProvider()

        let redesignViewController = MainTabBarViewFactory.createWalletRedesignController(walletContext: walletContext,
                                                                                          assetManager: assetManager,
                                                                                          poolsService: poolsService,
                                                                                          assetsProvider: assetsProvider,
                                                                                          poolsViewModelService: poolsViewModelService,
                                                                                          assetsViewModelService: assetsViewModelService,
                                                                                          editViewService: editViewService, 
                                                                                          accountSettings: accountSettings,
                                                                                          farmingService: farmingService, 
                                                                                          feeProvider: feeProvider,
                                                                                          localizationManager: LocalizationManager.shared)

        let investController = MainTabBarViewFactory.createInvestController(walletContext: walletContext,
                                                                            assetManager: assetManager,
                                                                            networkFacade: walletContext.networkOperationFactory,
                                                                            polkaswapNetworkFacade: polkaswapContext,
                                                                            poolsService: poolsService,
                                                                            accountSettings: accountSettings,
                                                                            assetsProvider: assetsProvider,
                                                                            farmingService: farmingService, 
                                                                            feeProvider: feeProvider,
                                                                            walletAssets: assetInfos)

        guard let tabBarController = view as? UITabBarController else {
            return
        }

        if var viewcontrollers = tabBarController.viewControllers {
            viewcontrollers.remove(at: 0)
            viewcontrollers.insert(redesignViewController ?? UIViewController(), at: 0)
            tabBarController.viewControllers = viewcontrollers
        }
        
        if var viewcontrollers = tabBarController.viewControllers {
            viewcontrollers.remove(at: 1)
            viewcontrollers.insert(investController ?? UIViewController(), at: 1)
            tabBarController.viewControllers = viewcontrollers
        }
        
        if var viewcontrollers = tabBarController.viewControllers {
            guard let activityController = MainTabBarViewFactory.createActivityController(with: assetManager,
                                                                                          assetInfos: assetInfos) else { return }
            
            viewcontrollers.remove(at: 3)
            viewcontrollers.insert(activityController, at: 3)
            tabBarController.viewControllers = viewcontrollers
        }
        
        if var viewcontrollers = tabBarController.viewControllers {
            view?.middleButtonHadler = {
                guard let swapViewController = MainTabBarViewFactory.createSwapController(walletContext: walletContext,
                                                                                          assetManager: assetManager,
                                                                                          assetsProvider: assetsProvider,
                                                                                          localizationManager: LocalizationManager.shared) else { return }
                
                guard let containerView = MainTabBarViewFactory.swapDisclamerController(completion: {
                    UserDefaults.standard.set(true, forKey: "isDisclamerShown")
                    view?.controller.present(swapViewController, animated: true)
                }) else { return }

                if ApplicationConfig.shared.isDisclamerShown {
                    view?.controller.present(swapViewController, animated: true)
                } else {
                    view?.controller.present(containerView, animated: true)
                }
            }

            let fakeSwapViewController = UIViewController()
            fakeSwapViewController.tabBarItem.isEnabled = false
            fakeSwapViewController.title = R.string.localizable.tabbarPolkaswapTitle(preferredLanguages: .currentLocale)
            viewcontrollers.remove(at: 2)
            viewcontrollers.insert(fakeSwapViewController, at: 2)
            tabBarController.viewControllers = viewcontrollers
        }
        
        tabBarController.tabBar.semanticContentAttribute = LocalizationManager.shared.isRightToLeft ? .forceRightToLeft : .forceLeftToRight
    }

    // MARK: Private

    private func canPresentImport(on view: UIViewController) -> Bool {
        if isAuthorizing || isAlreadyImporting(on: view) {
            return false
        }

        return true
    }

    private func isAlreadyImporting(on view: UIViewController) -> Bool {
        let topViewController = view.topModalViewController
        let topNavigationController: UINavigationController?

        if let navigationController = topViewController as? UINavigationController {
            topNavigationController = navigationController
        } else if let tabBarController = topViewController as? UITabBarController {
            topNavigationController = tabBarController.selectedViewController as? UINavigationController
        } else {
            topNavigationController = nil
        }

        return topNavigationController?.viewControllers.contains {
            if ($0 as? OnboardingMainViewProtocol) != nil || ($0 as? AccountImportViewProtocol) != nil {
                return true
            } else {
                return false
            }
        } ?? false
    }
}
