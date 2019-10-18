/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct ProjectFavoriteToggleEvent: EventProtocol {
    let projectId: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processProjectFavoriteToggle(event: self)
    }
}
