/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol NotificationsPresenterProtocol: class {}

protocol NotificationsWireframeProtocol: MessageViewDisplayProtocol {}

protocol NotificationsInteractorInputProtocol: class {}

protocol NotificationsInteractorOutputProtocol: class {
    func didCompleteNotificationsSetup()
    func didReceiveNotificationsSetup(error: Error)
    func didReceive(_ notification: SoraNotificationProtocol) -> Bool
}

protocol NotificationsInteractorFactoryProtocol: class {
    associatedtype InteractorType: NotificationsInteractorInputProtocol
    func createNotificationsInteractor() -> InteractorType
}

protocol NotificationsRegistrationProtocol: class {
    func registerNotifications(options: NotificationsOptions)
    func registerForRemoteNotifications()
}

protocol NotificationsServiceOutputProtocol: class {
    func didReceive(remoteToken: String)
    func didReceive(_ notification: SoraNotificationProtocol) -> Bool
}
