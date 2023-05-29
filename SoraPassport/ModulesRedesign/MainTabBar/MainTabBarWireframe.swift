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
            let presenter = view as? UIViewController,
            let walletContext = try? WalletContextFactory().createContext(connection: connection, presenter: presenter) else {
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
        
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        
        let poolService = PoolsService(operationManager: OperationManagerFacade.sharedManager,
                                       networkFacade: walletContext.networkOperationFactory,
                                       polkaswapNetworkFacade: polkaswapContext,
                                       config: ApplicationConfig.shared)

        let redesignViewController = MainTabBarViewFactory.createWalletRedesignController(walletContext: walletContext,
                                                                                          assetManager: assetManager,
                                                                                          poolsService: poolService,
                                                                                          assetsProvider: assetsProvider,
                                                                                          localizationManager: LocalizationManager.shared)
        
        let oldWalletViewController = MainTabBarViewFactory.createWalletController(walletContext: walletContext,
                                                                                  localizationManager: LocalizationManager.shared)

        guard let tabBarController = view as? UITabBarController else {
            return
        }

        if var viewcontrollers = tabBarController.viewControllers {
            viewcontrollers.remove(at: 0)
            viewcontrollers.insert(redesignViewController ?? UIViewController(), at: 0)
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
