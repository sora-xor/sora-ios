import Foundation
import UserNotifications

struct PushNotificationEvent: EventProtocol {
    let notification: SoraNotificationProtocol

    func accept(visitor: EventVisitorProtocol) {
        visitor.processPushNotification(event: self)
    }
}
