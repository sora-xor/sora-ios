/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

enum PersonalInfoViewModelIndex: Int {
    case firstName
    case lastName
    case phone
    case email
}

protocol PersonalInfoViewModelProtocol {
    var isComplete: Bool { get }
    var title: String { get }
    var value: String { get }
    var enabled: Bool { get }

    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool
}

class PersonalInfoViewModel {
    var title: String
    var value: String
    var enabled: Bool

    var invalidCharacterSet: CharacterSet?
    var maxLength: Int
    var predicate: NSPredicate?

    init(title: String, value: String, enabled: Bool = true, maxLength: Int = 0,
         validCharacterSet: CharacterSet? = nil, predicate: NSPredicate? = nil) {
        self.title = title
        self.value = value
        self.enabled = enabled
        self.maxLength = maxLength
        self.invalidCharacterSet = validCharacterSet?.inverted
        self.predicate = predicate
    }
}

extension PersonalInfoViewModel: PersonalInfoViewModelProtocol {
    var isComplete: Bool {
        if let predicate = predicate {
            return predicate.evaluate(with: value)
        } else {
            return true
        }
    }

    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool {
        let newLength = value.count - range.length + string.count
        guard maxLength == 0 || newLength <= maxLength else {
            return false
        }

        guard let currentInvalidSet = invalidCharacterSet,
            string.rangeOfCharacter(from: currentInvalidSet) == nil else {
            return false
        }

        let startIndex = value.index(value.startIndex, offsetBy: range.location)
        let endIndex = value.index(startIndex, offsetBy: range.length)
        value.replaceSubrange(startIndex..<endIndex, with: string)

        return true
    }
}
