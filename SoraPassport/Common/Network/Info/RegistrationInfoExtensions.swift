/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension RegistrationInfo {
    static func create(with form: PersonalForm) -> RegistrationInfo {
        let userInfo = RegistrationUserInfo(firstName: form.firstName,
                                            lastName: form.lastName,
                                            country: form.countryCode)
        return RegistrationInfo(userData: userInfo,
                                invitationCode: form.invitationCode)
    }
}
