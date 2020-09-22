/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension CharacterSet {
    static var personName: CharacterSet {
        CharacterSet.letters.union(CharacterSet.personNameSeparators)
    }

    static var personNameSeparators: CharacterSet {
        CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-'"))
    }

    static var email: CharacterSet {
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._%+-@"))
    }

    static var phone: CharacterSet {
        CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "+"))
    }
}
