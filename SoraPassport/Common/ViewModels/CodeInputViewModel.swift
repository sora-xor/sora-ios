/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol CodeInputViewModelProtocol {
    var code: String { get }
    var isComplete: Bool { get }

    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool
}

final class CodeInputViewModel {
    fileprivate(set) var code: String = ""

    var isComplete: Bool {
        return code.count == requiredLength
    }

    let invalidCharacters: CharacterSet
    let requiredLength: Int

    init(length: Int, invalidCharacters: CharacterSet) {
        self.requiredLength = length
        self.invalidCharacters = invalidCharacters
    }
}

extension CodeInputViewModel: CodeInputViewModelProtocol {
    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool {
        let newLength = code.count + string.count - range.length

        guard newLength <= requiredLength else {
            return false
        }

        guard string.rangeOfCharacter(from: invalidCharacters) == nil else {
            return false
        }

        let startIndex = code.index(code.startIndex, offsetBy: range.location)
        let endIndex = code.index(startIndex, offsetBy: range.length)
        code.replaceSubrange(startIndex..<endIndex, with: string)

        return true
    }
}
