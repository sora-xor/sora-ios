import Foundation
import CommonWallet
import SoraFoundation

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

        guard let migrationController = MigrationViewFactory.createView(with: service)?.controller else {
            return
        }
        let navigationController = SoraNavigationController(rootViewController: migrationController)
        navigationController.modalPresentationStyle = .overFullScreen

        let presentingController = tabBarController.topModalViewController
        presentingController.present(navigationController, animated: true, completion: nil)

    }

    func presentAccountImport(on view: MainTabBarViewProtocol?) {
        guard let tabBarController = view?.controller else {
            return
        }

        guard canPresentImport(on: tabBarController) else {
            return
        }

        guard let importController = AccountImportViewFactory
            .createViewForAdding()?.controller else {
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
            let walletContext = try? WalletContextFactory().createContext(connection: connection, presenter: presenter),
            let walletController = MainTabBarViewFactory.createWalletController(walletContext: walletContext,
                                                                                localizationManager: LocalizationManager.shared)
        else {
            return
        }

        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)
        guard let polkaswapController = MainTabBarViewFactory.createPolkaswapController(walletContext: walletContext,
                                                                                        polkaswapContext: polkaswapContext,
                                                                                        localizationManager: LocalizationManager.shared) else {
            return
        }

        guard let tabBarController = view as? UITabBarController else {
            return
        }

        if var viewcontrollers = tabBarController.viewControllers {
            viewcontrollers.remove(at: 0)
            viewcontrollers.insert(walletController, at: 0)
            tabBarController.viewControllers = viewcontrollers
        }
        
        if var viewcontrollers = tabBarController.viewControllers {
            viewcontrollers.remove(at: 1)
            viewcontrollers.insert(polkaswapController, at: 1)
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
