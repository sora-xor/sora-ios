/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import Firebase
import UserNotifications

class NotificationsService {
    private static let messageHandler = FirebaseNotificationsHandler()
    private static let nativeNotificationsHandler = NativeNotificationsHandler()

    static let sharedNotificationsInteractor: NotificationsInteractor = {
        let interactor = NotificationsInteractorFactory().createNotificationsInteractor()
        startFirebaseAndBind(interactor: interactor, messageHandler: messageHandler)
        configureNativeNotificationsHandler(for: interactor)
        return interactor
    }()

    private static func startFirebaseAndBind(interactor: NotificationsInteractor,
                                             messageHandler: FirebaseNotificationsHandler) {
        FirebaseApp.configure()
        NotificationsService.messageHandler.serviceOutput = interactor
        Messaging.messaging().delegate = messageHandler
    }

    private static func configureNativeNotificationsHandler(for delegate: NotificationsServiceOutputProtocol) {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = nativeNotificationsHandler
            nativeNotificationsHandler.delegate = delegate
        }
    }
}

class FirebaseNotificationsHandler: NSObject, MessagingDelegate {
    weak var serviceOutput: NotificationsServiceOutputProtocol?

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        serviceOutput?.didReceive(remoteToken: fcmToken)
    }
}

class NativeNotificationsHandler: NSObject, UNUserNotificationCenterDelegate {
    weak var delegate: NotificationsServiceOutputProtocol?

    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        guard
            let delegate = delegate,
            let soraNotification = ApnNotificationFactory.createNotification(from: notification) else {
                completionHandler([.alert, .sound])
                return
        }

        if delegate.didReceive(soraNotification) {
            completionHandler([])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}
