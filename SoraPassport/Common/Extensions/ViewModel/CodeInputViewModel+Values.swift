/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension CodeInputViewModel {
    static var invitation: CodeInputViewModel {
        return CodeInputViewModel(length: 8,
                                  invalidCharacters: CharacterSet.alphanumerics.inverted)
    }

    static var phone: CodeInputViewModel {
        return CodeInputViewModel(length: 4,
                                  invalidCharacters: CharacterSet.decimalDigits.inverted)
    }
}
