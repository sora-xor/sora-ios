/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class AccessRestoreViewModel {
    private(set) var phrase: String
    private(set) var invalidCharacterSet: CharacterSet
    private(set) var maxLength: UInt

    init(phrase: String, characterSet: CharacterSet, maxLength: UInt) {
        self.phrase = phrase
        self.invalidCharacterSet = characterSet.inverted
        self.maxLength = maxLength
    }
}

extension AccessRestoreViewModel: AccessRestoreViewModelProtocol {
    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool {
        let newLength = phrase.count - range.length + string.count
        guard maxLength == 0 || newLength <= maxLength else {
            return false
        }

        guard string.rangeOfCharacter(from: invalidCharacterSet) == nil else {
                return false
        }

        let startIndex = phrase.index(phrase.startIndex, offsetBy: range.location)
        let endIndex = phrase.index(startIndex, offsetBy: range.length)
        phrase.replaceSubrange(startIndex..<endIndex, with: string)

        return true
    }
}
