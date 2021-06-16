/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct MigrationEvent: EventProtocol {

    let service: MigrationServiceProtocol

    func accept(visitor: EventVisitorProtocol) {
        visitor.processMigration(event: self)
    }
}

struct MigrationSuccsessEvent: EventProtocol {

    let service: MigrationServiceProtocol

    func accept(visitor: EventVisitorProtocol) {
        visitor.processSuccsessMigration(event: self)
    }
}
