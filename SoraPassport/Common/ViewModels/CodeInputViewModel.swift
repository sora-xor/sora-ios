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
        let newValue = (code as NSString).replacingCharacters(in: range, with: string)

        if requiredLength > 0, newValue.count > requiredLength {
            return false
        }

        if newValue.rangeOfCharacter(from: invalidCharacters) != nil {
            return false
        }

        code = newValue

        return true
    }
}
