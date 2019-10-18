/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct ProjectViewEvent: EventProtocol {
    let projectId: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processProjectView(event: self)
    }
}
