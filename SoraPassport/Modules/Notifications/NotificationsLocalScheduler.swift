/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import UserNotifications

class NotificationsLocalScheduler: NotificationsLocalSchedulerProtocol {
    func schedule(notification: SoraNotification, with identifier: String, on date: Date?) {
        if #available(iOS 10.0, *) {
            scheduleNewStyle(notification: notification, with: identifier, on: date)
        } else {
            scheduleOldStyle(notification: notification, on: date)
        }
    }

    @available(iOS 10.0, *)
    private func scheduleNewStyle(notification: SoraNotification, with identifier: String, on date: Date?) {
        let localNotification = UNMutableNotificationContent()

        if let existingTitle = notification.title {
            localNotification.title = existingTitle
        }

        if let existingBody = notification.body {
            localNotification.body = existingBody
        }

        let timeinterval = date?.timeIntervalSince(Date()) ?? 0.0
        let trigger = timeinterval > 0.0
            ? UNTimeIntervalNotificationTrigger(timeInterval: timeinterval, repeats: false) : nil

        let request = UNNotificationRequest(identifier: identifier, content: localNotification, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func scheduleOldStyle(notification: SoraNotification, on date: Date?) {
        let localNotification = UILocalNotification()
        localNotification.alertTitle = notification.title
        localNotification.alertBody = notification.body
        localNotification.fireDate = date

        UIApplication.shared.scheduleLocalNotification(localNotification)
    }
}
