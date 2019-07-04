/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

struct InvitationCodeData: Decodable {
    enum CodingKeys: String, CodingKey {
        case invitationCode
        case invitationsCount
    }

    var invitationCode: String
    var invitationsCount: Int
}
