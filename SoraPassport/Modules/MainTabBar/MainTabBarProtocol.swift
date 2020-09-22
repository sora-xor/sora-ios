/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    func didReplaceView(for newView: UIViewController, for index: Int)
}

protocol MainTabBarPresenterProtocol: class {
    func setup()
    func viewDidAppear()
}

protocol MainTabBarInteractorInputProtocol: class {
    func configureNotifications()
    func configureDeepLink()

    func searchPendingDeepLink()
    func resolvePendingDeepLink()
}

protocol MainTabBarInteractorOutputProtocol: class {
    func didReceive(deepLink: DeepLinkProtocol)
}

protocol MainTabBarWireframeProtocol: AlertPresentable {}

protocol MainTabBarViewFactoryProtocol: class {
    static func createView() -> MainTabBarViewProtocol?
}
