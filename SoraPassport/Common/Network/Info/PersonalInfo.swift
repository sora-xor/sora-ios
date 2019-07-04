/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

struct PersonalInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case firstName
        case lastName
        case email
    }

    var firstName: String?
    var lastName: String?
    var email: String?
}
