/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct ParentInfoData: Codable, Equatable {
    var firstName: String
    var lastName: String
}

extension ParentInfoData {
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}
