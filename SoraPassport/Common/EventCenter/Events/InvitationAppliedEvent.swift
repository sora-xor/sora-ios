/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct InvitationAppliedEvent: EventProtocol {
    let code: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processInvitationApplied(event: self)
    }
}
