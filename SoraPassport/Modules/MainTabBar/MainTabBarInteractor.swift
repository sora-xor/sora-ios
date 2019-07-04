/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class MainTabBarInteractor {
	weak var presenter: MainTabBarInteractorOutputProtocol?

    private(set) var applicationConfig: ApplicationConfigProtocol
    private(set) var notificationRegistrator: NotificationsRegistrationProtocol

    init(applicationConfig: ApplicationConfigProtocol,
         notificationRegistrator: NotificationsRegistrationProtocol) {

        self.applicationConfig = applicationConfig
        self.notificationRegistrator = notificationRegistrator
    }
}

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {
    func configureNotifications() {
        let options = NotificationsOptions(rawValue: applicationConfig.notificationOptions)
        notificationRegistrator.registerNotifications(options: options)
        notificationRegistrator.registerForRemoteNotifications()
    }
}
