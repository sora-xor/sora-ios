/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension CharacterSet {
    static var personName: CharacterSet {
        return CharacterSet.letters
            .union(CharacterSet.whitespaces)
            .union(CharacterSet(charactersIn: "-'"))
    }

    static var email: CharacterSet {
        return CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._%+-@"))
    }

    static var phone: CharacterSet {
        return CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "+"))
    }
}
