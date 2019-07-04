/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

struct UserData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case userId
        case firstName
        case lastName
        case email
        case phone
        case parentId
        case status
        case services = "userServices"
        case values = "userValues"
    }

    var userId: String
    var firstName: String
    var lastName: String
    var email: String
    var phone: String?
    var parentId: String?
    var status: String?
    var services: [UserServiceData]?
    var values: UserValuesData
}
