/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UserNotifications

public protocol SoraNotificationProtocol {
    var title: String? { get }
    var body: String? { get }
}

public protocol NotificationFactoryProtocol {
    static func createNotification(from payload: [AnyHashable: Any]) -> SoraNotificationProtocol?

    @available(iOS 10.0, *)
    static func createNotification(from userNotification: UNNotification) -> SoraNotificationProtocol?
}

public struct SoraNotification: SoraNotificationProtocol, Equatable, Codable {
    public var title: String?
    public var body: String?
}

public enum ApnNotificationKeys {
    public static let aps = "aps"
    public static let alert = "alert"
    public static let title = "title"
    public static let body = "body"
}

public class ApnNotificationFactory: NotificationFactoryProtocol {
    static public func createNotification(from payload: [AnyHashable: Any]) -> SoraNotificationProtocol? {
        guard let aps = payload[ApnNotificationKeys.aps] as? [AnyHashable: Any] else {
            return nil
        }

        var notification = SoraNotification()

        if let alert = aps[ApnNotificationKeys.alert] as? String {
            notification.body = alert
            return notification
        }

        guard let alert = aps[ApnNotificationKeys.alert] as? [AnyHashable: Any] else {
            return nil
        }

        notification.title = alert[ApnNotificationKeys.title] as? String
        notification.body = alert[ApnNotificationKeys.body] as? String

        return notification
    }

    @available(iOS 10.0, *)
    public static func createNotification(from userNotification: UNNotification) -> SoraNotificationProtocol? {
        return SoraNotification(title: userNotification.request.content.title,
                                body: userNotification.request.content.body)

    }
}
