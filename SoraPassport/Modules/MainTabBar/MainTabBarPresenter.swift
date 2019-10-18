/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class MainTabBarPresenter {
	weak var view: MainTabBarViewProtocol?
	var interactor: MainTabBarInteractorInputProtocol!
	var wireframe: MainTabBarWireframeProtocol!

    var logger: LoggerProtocol?

    private var shouldRequestNotificationConfiguration: Bool = true
    private var shouldRequestDeepLinkConfiguration: Bool = true
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func viewIsReady() {
        if shouldRequestNotificationConfiguration {
            shouldRequestNotificationConfiguration = false
            interactor.configureNotifications()
        }
    }

    func viewDidAppear() {
        if shouldRequestDeepLinkConfiguration {
            shouldRequestDeepLinkConfiguration = false
            interactor.configureDeepLink()
        }

        interactor.searchPendingDeepLink()
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didReceive(deepLink: DeepLinkProtocol) {
        if deepLink.accept(navigator: wireframe) {
            interactor.resolvePendingDeepLink()
        }
    }
}
