/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import UserNotifications

class NotificationsRegistration: NotificationsRegistrationProtocol {
    func registerNotifications(options: NotificationsOptions) {
        if #available(iOS 10.0, *) {
            registerForNewStyleNotifications(with: options)
        } else {
            registerForOldStyleNotifications(with: options)
        }
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    @available(iOS 10.0, *)
    private func registerForNewStyleNotifications(with options: NotificationsOptions) {
        let authOptions = extractNewStyleNotificationOptions(from: options)
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions, completionHandler: { _, _ in })
    }

    private func registerForOldStyleNotifications(with options: NotificationsOptions) {
        let types = extractOldStyleNotificationTypes(from: options)
        let settings = UIUserNotificationSettings(types: types, categories: nil)
        UIApplication.shared.registerUserNotificationSettings(settings)
    }

    @available(iOS 10.0, *)
    private func extractNewStyleNotificationOptions(from options: NotificationsOptions) -> UNAuthorizationOptions {
        var authOptions = UNAuthorizationOptions()

        if options.contains(.alert) {
            authOptions.formUnion(.alert)
        }

        if options.contains(.badge) {
            authOptions.formUnion(.badge)
        }

        if options.contains(.sound) {
            authOptions.formUnion(.sound)
        }

        return authOptions
    }

    private func extractOldStyleNotificationTypes(from options: NotificationsOptions) -> UIUserNotificationType {
        var types = UIUserNotificationType()

        if options.contains(.alert) {
            types.formUnion(.alert)
        }

        if options.contains(.badge) {
            types.formUnion(.badge)
        }

        if options.contains(.sound) {
            types.formUnion(.sound)
        }

        return types
    }
}
