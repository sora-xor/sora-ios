/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraCrypto
import SoraKeystore
import CommonWallet

final class MainTabBarViewFactory: MainTabBarViewFactoryProtocol {
	static func createView() -> MainTabBarViewProtocol? {
        guard let activityController = createActivityController() else {
            return nil
        }

        guard let projectsController = createProjectsController() else {
            return nil
        }

        guard
            let walletContext = WalletContextFactory.createContext(),
            let walletController = createWalletController(from: walletContext) else {
            return nil
        }

        guard let profileController = createProfileController() else {
            return nil
        }

        guard let friendsController = createFriendsController() else {
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

        let notificationRegistrator = NotificationsService.sharedNotificationsInteractor.notificationsRegistrator
        let interactor = MainTabBarInteractor(eventCenter: EventCenter.shared,
                                              settings: SettingsManager.shared,
                                              applicationConfig: ApplicationConfig.shared,
                                              applicationHandler: ApplicationHandler(),
                                              notificationRegistrator: notificationRegistrator,
                                              invitationLinkService: invitationLinkService,
                                              walletContext: walletContext)

        let wireframe = MainTabBarWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
	}

    static func createActivityController() -> UIViewController? {
        guard let activityView = ActivityFeedViewFactory.createView() else {
            return nil
        }

        let navigationController = SoraNavigationController()

        navigationController.tabBarItem = createTabBarItem(title: R.string.localizable.tabbarActivityTitle(),
                                                           normalImage: R.image.tabActivity(),
                                                           selectedImage: R.image.tabActivitySel())

        navigationController.viewControllers = [activityView.controller]

        return navigationController
    }

    static func preparePresenterChildren(for view: ControllerBackedProtocol) -> [ChildPresenterProtocol] {
        var children: [ChildPresenterProtocol] = []

        if let invitationHandlePresenter = InvitationHandlePresenterFactory.createPresenter(for: view) {
            children.append(invitationHandlePresenter)
        }

        return children
    }

    static func createProjectsController() -> UIViewController? {
        guard let projectsView = ProjectsViewFactory.createView() else {
            return nil
        }

        let navigationController = SoraNavigationController()

        navigationController.tabBarItem = createTabBarItem(title: R.string.localizable.tabbarProjectsTitle(),
                                                           normalImage: R.image.tabProjects(),
                                                           selectedImage: R.image.tabProjectsSel())

        navigationController.viewControllers = [projectsView.controller]

        return navigationController
    }

    static func createWalletController(from context: CommonWalletContextProtocol) -> UIViewController? {
        guard let walletController = try? context.createRootController() else {
            return nil
        }

        walletController.tabBarItem = createTabBarItem(title: R.string.localizable.tabbarWalletTitle(),
                                                       normalImage: R.image.tabWallet(),
                                                       selectedImage: R.image.tabWalletSel())

        return walletController
    }

    static func createProfileController() -> UIViewController? {
        guard let profileView = ProfileViewFactory.createView() else {
            return nil
        }

        let navigationController = SoraNavigationController()

        navigationController.tabBarItem = createTabBarItem(title: R.string.localizable.tabbarProfileTitle(),
                                                           normalImage: R.image.tabProfile(),
                                                           selectedImage: R.image.tabProfileSel())

        navigationController.viewControllers = [profileView.controller]

        return navigationController
    }

    static func createFriendsController() -> UIViewController? {
        guard let friendsView = InvitationViewFactory.createView() else {
            return nil
        }

        friendsView.controller.tabBarItem = createTabBarItem(title: R.string.localizable.tabbarFriendsTitle(),
                                                             normalImage: R.image.tabFriends(),
                                                             selectedImage: R.image.tabFriendsSel())

        let navigationController = SoraNavigationController()
        navigationController.viewControllers = [friendsView.controller]

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
