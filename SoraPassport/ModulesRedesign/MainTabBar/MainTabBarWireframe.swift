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

import Foundation
import CommonWallet
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

    func presentClaim(on view: MainTabBarViewProtocol?, with service: MigrationServiceProtocol) {
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
    
    func recreateWalletViewController(on view: MainTabBarViewProtocol?) {
        guard
            let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()),
            let walletContext = try? WalletContextFactory().createContext(connection: connection) else {
            return
        }
        
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        
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
        
        let assetViewModelsFactory = AssetViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
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
        
        let factory = PoolViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                           fiatService: FiatService.shared)
        
        let poolsViewModelService = PoolsItemService(marketCapService: MarketCapService.shared,
                                           fiatService: FiatService.shared,
                                           poolViewModelsFactory: factory)
        poolsService.appendDelegate(delegate: poolsViewModelService)


        let redesignViewController = MainTabBarViewFactory.createWalletRedesignController(walletContext: walletContext,
                                                                                          assetManager: assetManager,
                                                                                          poolsService: poolsService,
                                                                                          assetsProvider: assetsProvider,
                                                                                          poolsViewModelService: poolsViewModelService,
                                                                                          assetsViewModelService: assetsViewModelService,
                                                                                          localizationManager: LocalizationManager.shared)

        let investController = MainTabBarViewFactory.createInvestController(walletContext: walletContext,
                                                                            assetManager: assetManager,
                                                                            networkFacade: walletContext.networkOperationFactory,
                                                                            polkaswapNetworkFacade: polkaswapContext,
                                                                            poolsService: poolsService,
                                                                            assetsProvider: assetsProvider)

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
            guard let activityController = MainTabBarViewFactory.createActivityController(with: assetManager) else { return }
            
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
            fakeSwapViewController.title = R.string.localizable.polkaswapSwapTitle(preferredLanguages: .currentLocale)
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
