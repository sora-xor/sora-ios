import UIKit
import SoraCrypto
import SoraKeystore
import CommonWallet
import SoraFoundation

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
	static func createView() -> MainTabBarViewProtocol? {
        let localizationManager = LocalizationManager.shared

        guard let activityController = createActivityController(for: localizationManager) else {
            return nil
        }

        guard let projectsController = createProjectsController(for: localizationManager) else {
            return nil
        }

        // TODO: use WalletContextFactory to enable ethereum features

        guard
            let walletContext = WalletContextFactoryV16.createContext(),
            let walletController = createWalletController(from: walletContext,
                                                          localizationManager: localizationManager) else {
            return nil
        }

        guard let profileController = createProfileController(for: localizationManager) else {
            return nil
        }

        guard let friendsController = createFriendsController(for: localizationManager) else {
            return nil
        }

        guard let invitationLinkService: InvitationLinkServiceProtocol = DeepLinkService.shared.findService() else {
            return nil
        }

        let view = MainTabBarViewController()
        view.viewControllers = [activityController, projectsController, walletController,
                                profileController, friendsController]

        let children = preparePresenterChildren(for: view)
        let presenter = MainTabBarPresenter(children: children)

        let notificationRegistrator = NotificationService.sharedNotificationsInteractor.notificationsRegistrator

        let userServices = createUserServices()

        let interactor = MainTabBarInteractor(eventCenter: EventCenter.shared,
                                              settings: SettingsManager.shared,
                                              applicationConfig: ApplicationConfig.shared,
                                              applicationHandler: ApplicationHandler(),
                                              notificationRegistrator: notificationRegistrator,
                                              invitationLinkService: invitationLinkService,
                                              walletContext: walletContext,
                                              userServices: userServices)

        let wireframe = MainTabBarWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
	}

    static func createUserServices() -> [UserApplicationServiceProtocol] {
        // TODO: ethereum services disabled until v1.7
        /*
        let dataStreamService = DataStreamService()
        let pollingServices = PollingServiceFactory().createServices()
        let walletServices = WalletOperationFinalizationFactory().createServices()
        let registrationServices = EthereumUserServiceFactory().createServices()
        let historyUpdateServices = HistoryListeningServiceFactory().createServices()
        return [dataStreamService] + registrationServices +
            walletServices + pollingServices + historyUpdateServices
        */

        let eventProcessor = EventCenterProcessor(eventCenter: EventCenter.shared)
        let dataStreamService = DataStreamService(processors: [eventProcessor])
        return [dataStreamService]
    }

    static func createActivityController(for localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        guard let activityView = ActivityFeedViewFactory.createView() else {
            return nil
        }

        let navigationController = SoraNavigationController()

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarActivityTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
        navigationController.tabBarItem = createTabBarItem(title: currentTitle,
                                                           normalImage: R.image.tabActivity(),
                                                           selectedImage: R.image.tabActivitySel())

        navigationController.viewControllers = [activityView.controller]

        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }

        return navigationController
    }

    static func preparePresenterChildren(for view: ControllerBackedProtocol) -> [ChildPresenterProtocol] {
        var children: [ChildPresenterProtocol] = []

        if let invitationHandlePresenter = InvitationHandlePresenterFactory.createPresenter(for: view) {
            children.append(invitationHandlePresenter)
        }

        return children
    }

    static func createProjectsController(for localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        guard let projectsView = ProjectsViewFactory.createView() else {
            return nil
        }

        let navigationController = SoraNavigationController()

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarVotingTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        navigationController.tabBarItem = createTabBarItem(title: currentTitle,
                                                           normalImage: R.image.tabProjects(),
                                                           selectedImage: R.image.tabProjectsSel())

        navigationController.viewControllers = [projectsView.controller]

        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }

        return navigationController
    }

    static func createWalletController(from context: CommonWalletContextProtocol,
                                       localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        guard let walletController = try? context.createRootController() else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarWalletTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        walletController.tabBarItem = createTabBarItem(title: currentTitle,
                                                       normalImage: R.image.tabWallet(),
                                                       selectedImage: R.image.tabWalletSel())

        localizationManager.addObserver(with: walletController) { [weak walletController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            walletController?.tabBarItem.title = currentTitle
        }

        return walletController
    }

    static func createProfileController(for localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        guard let profileView = ProfileViewFactory.createView() else {
            return nil
        }

        let navigationController = SoraNavigationController()

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarProfileTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        navigationController.tabBarItem = createTabBarItem(title: currentTitle,
                                                           normalImage: R.image.tabProfile(),
                                                           selectedImage: R.image.tabProfileSel())

        navigationController.viewControllers = [profileView.controller]

        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }

        return navigationController
    }

    static func createFriendsController(for localizationManager: LocalizationManagerProtocol)
        -> UIViewController? {
        guard let friendsView = InvitationViewFactory.createView() else {
            return nil
        }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.tabbarFriendsTitle(preferredLanguages: locale.rLanguages)
        }

        let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)

        friendsView.controller.tabBarItem = createTabBarItem(title: currentTitle,
                                                             normalImage: R.image.tabFriends(),
                                                             selectedImage: R.image.tabFriendsSel())

        let navigationController = SoraNavigationController()
        navigationController.viewControllers = [friendsView.controller]

        localizationManager.addObserver(with: navigationController) { [weak navigationController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            navigationController?.tabBarItem.title = currentTitle
        }

        return navigationController
    }

    static func createTabBarItem(title: String,
                                 normalImage: UIImage?,
                                 selectedImage: UIImage?) -> UITabBarItem {

        let tabBarItem = UITabBarItem(title: title,
                                      image: normalImage,
                                      selectedImage: selectedImage)

        // Style is set here for compatibility reasons for iOS 12.x and less.
        // For iOS 13 styling see MainTabBarViewController's 'configure' method.

        if #available(iOS 13.0, *) {
            return tabBarItem
        }

        let normalAttributes = [NSAttributedString.Key.foregroundColor: UIColor.tabBarItemNormal]
        let selectedAttributes = [NSAttributedString.Key.foregroundColor: UIColor.tabBarItemSelected]

        tabBarItem.setTitleTextAttributes(normalAttributes, for: .normal)
        tabBarItem.setTitleTextAttributes(selectedAttributes, for: .selected)

        return tabBarItem
    }
}
