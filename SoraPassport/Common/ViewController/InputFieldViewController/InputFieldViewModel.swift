// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

protocol InputFieldViewModelDelegate: AnyObject {
    func inputFieldDidCompleteInput(to viewModel: InputFieldViewModelProtocol)
    func inputFieldDidCancelInput(to viewModel: InputFieldViewModelProtocol)
}

protocol InputFieldViewModelProtocol {
    var title: String { get }
    var hint: String { get }
    var cancelActionTitle: String { get }
    var doneActionTitle: String { get }

    var value: String { get }

    var isComplete: Bool { get }

    var delegate: InputFieldViewModelDelegate? { get }

    func didReceive(replacement: String, in range: NSRange) -> Bool
}

class InputFieldViewModel: InputFieldViewModelProtocol {
    let title: String
    let hint: String
    let cancelActionTitle: String
    let doneActionTitle: String

    weak var delegate: InputFieldViewModelDelegate?

    var completionPredicate: NSPredicate?
    var invalidCharacters: CharacterSet?
    var maximumLength: Int = 0

    var isComplete: Bool {
        if let predicate = completionPredicate {
            return predicate.evaluate(with: value)
        } else {
            return true
        }
    }

    private(set) var value: String = ""

    init(title: String, hint: String, cancelActionTitle: String, doneActionTitle: String) {
        self.title = title
        self.hint = hint
        self.cancelActionTitle = cancelActionTitle
        self.doneActionTitle = doneActionTitle
    }

    func didReceive(replacement: String, in range: NSRange) -> Bool {
        let newValue = (value as NSString).replacingCharacters(in: range, with: replacement)

        if maximumLength > 0, newValue.count > maximumLength {
            return false
        }

        if let invalidCharacters = invalidCharacters, newValue.rangeOfCharacter(from: invalidCharacters) != nil {
            return false
        }

        value = newValue

        return true
    }
}
