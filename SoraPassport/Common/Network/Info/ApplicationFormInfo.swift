/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

struct ApplicationFormInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case applicationId = "uid"
        case firstName
        case lastName
        case phone
        case email
    }

    var applicationId: String?
    var firstName: String
    var lastName: String
    var phone: String
    var email: String
}
