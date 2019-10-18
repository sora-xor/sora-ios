/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct UserData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case userId
        case firstName
        case lastName
        case country
        case phone
        case parentId
        case status
        case services = "userServices"
        case values = "userValues"
    }

    var userId: String
    var firstName: String
    var lastName: String
    var country: String?
    var phone: String?
    var parentId: String?
    var status: String?
    var services: [UserServiceData]?
    var values: UserValuesData
}
