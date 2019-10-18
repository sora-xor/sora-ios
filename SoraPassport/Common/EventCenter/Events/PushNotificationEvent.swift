/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UserNotifications

struct PushNotificationEvent: EventProtocol {
    let notification: SoraNotificationProtocol

    func accept(visitor: EventVisitorProtocol) {
        visitor.processPushNotification(event: self)
    }
}
