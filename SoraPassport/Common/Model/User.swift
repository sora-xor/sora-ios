/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

enum UserStatus: Int, Codable {
    case proccessing
    case registered
    case blacklisted
}

struct User: Codable, Equatable {
    var decentralizedId: String
    var email: String
    var firstName: String
    var lastName: String
    var phone: String?
    var invitee: String?
    var status: UserStatus
}
