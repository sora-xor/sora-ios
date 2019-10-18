/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol PersonalInfoViewModelProtocol {
    var isComplete: Bool { get }
    var title: String { get }
    var value: String { get }
    var enabled: Bool { get }
    var autocapitalizationType: UITextAutocapitalizationType { get }

    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool
}

class PersonalInfoViewModel {
    var title: String
    var value: String
    var enabled: Bool

    var invalidCharacterSet: CharacterSet?
    var maxLength: Int
    var minLength: Int
    var predicate: NSPredicate?

    var autocapitalizationType: UITextAutocapitalizationType

    init(title: String,
         value: String,
         enabled: Bool = true,
         minLength: Int = 0,
         maxLength: Int = Int.max,
         validCharacterSet: CharacterSet? = nil,
         predicate: NSPredicate? = nil,
         autocapitalizationType: UITextAutocapitalizationType = .sentences) {
        self.title = title
        self.value = value
        self.enabled = enabled

        self.minLength = min(minLength, maxLength)

        if value.count < self.minLength {
            self.minLength = value.count
        }

        self.maxLength = max(self.minLength, maxLength)

        if value.count > self.maxLength {
            self.maxLength = value.count
        }

        self.invalidCharacterSet = validCharacterSet?.inverted
        self.predicate = predicate

        self.autocapitalizationType = autocapitalizationType
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
        guard enabled else {
            return false
        }

        let newValue = (value as NSString).replacingCharacters(in: range, with: string)

        guard newValue.count >= minLength, newValue.count <= maxLength else {
            return false
        }

        guard let currentInvalidSet = invalidCharacterSet,
            string.rangeOfCharacter(from: currentInvalidSet) == nil else {
            return false
        }

        value = newValue

        return true
    }
}
