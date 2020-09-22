/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class EventCenterProcessor {
    let eventCenter: EventCenterProtocol

    init(eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter
    }
}

extension EventCenterProcessor: DataStreamProcessing {
    func processOutOfSync() {}

    func process(event: DataStreamOneOfEvent) {
        eventCenter.notify(with: WalletUpdateEvent())
    }
}
