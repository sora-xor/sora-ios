/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

extension CharacterSet {
    static var englishMnemonic: CharacterSet {
        return CharacterSet(charactersIn: "a"..."z")
            .union(wordsSeparator)
    }

    static var wordsSeparator: CharacterSet {
        return CharacterSet.whitespaces
    }
}
