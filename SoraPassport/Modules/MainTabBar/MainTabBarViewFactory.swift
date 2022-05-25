import UIKit
import SoraKeystore
import CommonWallet
import SoraFoundation
import Then

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
    static let walletIndex: Int = 0

    static func createView() -> MainTabBarViewProtocol? {

        guard let keystoreImportService: KeystoreImportServiceProtocol = URLHandlingService.shared
                .findService() else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let serviceCoordinator = ServiceCoordinator.createDefault()

        let interactor = MainTabBarInteractor(eventCenter: EventCenter.shared,
                                              settings: SettingsManager.shared,
                                              serviceCoordinator: serviceCoordinator,
                                              keystoreImportService: keystoreImportService)

        guard
            let walletContext = try? WalletContextFactory().createContext(),
            let walletController = createWalletController(walletContext: walletContext,
                                                          localizationManager: localizationManager)
            else {
            return nil
        }

        guard let stakingController = createStakingController(for: localizationManager) else {
            return nil
        }

        guard let engine = WebSocketService.shared.connection else {
            return nil
        }
        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: engine)
        guard let polkaswapController = createPolkaswapController(walletContext: walletContext,
                                                                  polkaswapContext: polkaswapContext,
                                                                  localizationManager: localizationManager) else {
            return nil
        }

        guard let settingsController = createProfileController(for: localizationManager) else {
            return nil
        }

        guard let parliamentController = createParliamentController(for: localizationManager) else {
            return nil
        }

        let view = MainTabBarViewController()
        view.viewControllers = [
            walletController,
            polkaswapController,
//            parliamentController, SN-1199
            stakingController,
            settingsController
        ]

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

        guard
            let walletContext = try? WalletContextFactory().createContext(),
            let walletController = createWalletController(walletContext: walletContext,
                                                          localizationManager: localizationManager)
            else {
            return
        }

        wireframe.walletContext = walletContext
        view.didReplaceView(for: walletController, for: Self.walletIndex)
    }
}

private extension MainTabBarViewFactory {

    static func preparePresenterChildren(for view: ControllerBackedProtocol) -> [ChildPresenterProtocol] {
        var children: [ChildPresenterProtocol] = []

        if let invitationHandlePresenter = InvitationHandlePresenterFactory.createPresenter(for: view) {
            children.append(invitationHandlePresenter)
        }

        return children
    }

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

    static func createWalletController(walletContext: CommonWalletContextProtocol,
                                       localizationManager: LocalizationManagerProtocol) -> UIViewController? {

        guard let walletController = try? walletContext.createRootController() else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarWalletTitle(preferredLanguages: locale.rLanguages)
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

    static func createPolkaswapController(walletContext: CommonWalletContextProtocol,
                                          polkaswapContext: PolkaswapNetworkOperationFactoryProtocol,
                                          localizationManager: LocalizationManagerProtocol) -> UIViewController? {
        guard let view = PolkaswapMainViewFactory.createView(walletContext: walletContext, polkaswapContext: polkaswapContext) else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarPolkaswapTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        let navigationController = SoraNavigationController().then {
            $0.navigationBar.topItem?.title = currentTitle
            $0.navigationBar.layoutMargins.left = 16
            $0.navigationBar.layoutMargins.right = 16
            $0.tabBarItem = createTabBarItem(title: currentTitle, image: R.image.tabBar.polkaswap())
            $0.viewControllers = [view.controller]
        }

        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }

        return navigationController
    }

    static func createParliamentController(for localizationManager: LocalizationManagerProtocol) -> UIViewController? {
        guard let view = ParliamentViewFactory.createView() else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarParliamentTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        let navigationController = SoraNavigationController().then {
            $0.navigationBar.topItem?.title = currentTitle
            $0.navigationBar.prefersLargeTitles = true
            $0.navigationBar.layoutMargins.left = 16
            $0.navigationBar.layoutMargins.right = 16
            $0.tabBarItem = createTabBarItem(title: currentTitle, image: R.image.tabBar.parliament())
            $0.viewControllers = [view.controller]
        }

        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }

        return navigationController
    }

    static func createStakingController(for localizationManager: LocalizationManagerProtocol) -> UIViewController? {
        guard let view = StakingViewFactory.createView() else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarStakingTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        let navigationController = SoraNavigationController().then {
            $0.navigationBar.topItem?.title = currentTitle
            $0.navigationBar.prefersLargeTitles = true
            $0.navigationBar.layoutMargins.left = 16
            $0.navigationBar.layoutMargins.right = 16
            $0.tabBarItem = createTabBarItem(title: currentTitle, image: R.image.tabBar.staking())
            $0.viewControllers = [view.controller]
        }

        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }

        return navigationController
    }

    static func createProfileController(for localizationManager: LocalizationManagerProtocol) -> UIViewController? {
        guard let view = ProfileViewFactory.createView() else { return nil }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonSettings(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        let navigationController = SoraNavigationController().then {
            $0.navigationBar.topItem?.title = currentTitle
            $0.navigationBar.layoutMargins.left = 16
            $0.navigationBar.layoutMargins.right = 16
            $0.navigationBar.prefersLargeTitles = true
            $0.tabBarItem = createTabBarItem(title: currentTitle, image: R.image.tabBar.profile())
            $0.viewControllers = [view.controller]
        }

        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }

        return navigationController
    }

    static func createNetworkStatusPresenter(localizationManager: LocalizationManagerProtocol)
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
