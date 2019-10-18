/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol EventVisitorProtocol: class {
    func processPushNotification(event: PushNotificationEvent)
    func processProjectVote(event: ProjectVoteEvent)
    func processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent)
    func processProjectView(event: ProjectViewEvent)
}

extension EventVisitorProtocol {
    func processPushNotification(event: PushNotificationEvent) {}
    func processProjectVote(event: ProjectVoteEvent) {}
    func processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent) {}
    func processProjectView(event: ProjectViewEvent) {}
}
