/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

struct RegistrationInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case applicationForm = "applicationFormDTO"
        case invitationCode
    }

    var applicationForm: ApplicationFormInfo
    var invitationCode: String
}
