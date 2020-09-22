/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

class NotificationsPresenter: NotificationsPresenterProtocol {
    weak var view: UIWindow?
    var wireframe: NotificationsWireframeProtocol!

    var logger: LoggerProtocol?
}

extension NotificationsPresenter: NotificationsInteractorOutputProtocol {
    func didReceive(_ notification: SoraNotificationProtocol) -> Bool {
        return false
    }

    func didCompleteNotificationsSetup() {
        logger?.debug("Notifications successfully setup")
    }

    func didReceiveNotificationsSetup(error: Error) {
        logger?.warning("Did receive notification setup error: \(error)")
    }
}
