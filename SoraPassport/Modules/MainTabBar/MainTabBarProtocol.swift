/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol MainTabBarViewProtocol: ControllerBackedProtocol {}

protocol MainTabBarPresenterProtocol: class {
    func viewIsReady()
}

protocol MainTabBarInteractorInputProtocol: class {
    func configureNotifications()
}

protocol MainTabBarInteractorOutputProtocol: class {}

protocol MainTabBarWireframeProtocol: class {}

protocol MainTabBarViewFactoryProtocol: class {
    static func createView() -> MainTabBarViewProtocol?
}
