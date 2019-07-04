/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import IrohaCommunication

extension IRAccountIdFactory {
    static func createAccountIdFrom(decentralizedId: String, domain: IRDomain) throws -> IRAccountId {
        let accountName = decentralizedId.replacingOccurrences(of: ":", with: "_")
        return try accountId(withName: accountName, domain: domain)
    }
}
