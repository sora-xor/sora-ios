/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

class NotificationsPresenter: NotificationsPresenterProtocol {
    weak var view: UIWindow?
    var wireframe: NotificationsWireframeProtocol!

    var logger: LoggerProtocol?
}

extension NotificationsPresenter: NotificationsInteractorOutputProtocol {
    func didReceive(_ notification: SoraNotificationProtocol) {
        DispatchQueue.main.async { [weak self] in
            let message = SoraMessageBuilder()
                .with(title: notification.title)
                .with(subtitle: notification.body)
                .with(image: nil)
                .build()
            self?.wireframe.show(message: message, on: self?.view)
        }
    }

    func didCompleteNotificationsSetup() {
        logger?.debug("Notifications successfully setup")
    }

    func didReceiveNotificationsSetup(error: Error) {
        logger?.warning("Did receive notification setup error: \(error)")
    }
}
