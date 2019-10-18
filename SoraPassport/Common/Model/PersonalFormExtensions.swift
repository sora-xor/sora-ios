/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension PersonalForm {
    static func create(from country: Country) -> PersonalForm {
        return PersonalForm(firstName: "",
                            lastName: "",
                            countryCode: country.identitfier,
                            invitationCode: nil)
    }
}
