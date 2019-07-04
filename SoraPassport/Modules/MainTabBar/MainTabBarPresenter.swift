/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class MainTabBarPresenter {
	weak var view: MainTabBarViewProtocol?
	var interactor: MainTabBarInteractorInputProtocol!
	var wireframe: MainTabBarWireframeProtocol!

    private var shouldRequestNotificationConfiguration: Bool = true
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func viewIsReady() {
        if shouldRequestNotificationConfiguration {
            shouldRequestNotificationConfiguration = false
            interactor.configureNotifications()
        }
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {}
