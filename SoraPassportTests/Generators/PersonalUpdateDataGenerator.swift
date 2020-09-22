/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
@testable import SoraPassport

func createRandomPersonalUpdateInfo() -> PersonalInfo {
    let alphabetCharacterSet = CharacterSet.alphanumerics

    let filterBlock = { (value: Character) -> Bool in
        for scalar in value.unicodeScalars {
            if !alphabetCharacterSet.contains(scalar) {
                return false
            }
        }

        return true
    }

    let firstName = UUID().uuidString.filter(filterBlock)
    let lastName = UUID().uuidString.filter(filterBlock)
    let email = UUID().uuidString.filter(filterBlock) + "@gmail.com"

    return PersonalInfo(firstName: firstName, lastName: lastName, email: email)
}
