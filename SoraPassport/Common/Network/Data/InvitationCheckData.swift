/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct InvitationCheckData: Codable {
    enum CodingKeys: String, CodingKey {
        case code = "invitationCode"
    }

    let code: String?
}
