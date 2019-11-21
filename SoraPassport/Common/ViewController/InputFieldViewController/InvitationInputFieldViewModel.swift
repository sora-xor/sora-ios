/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class LowecasedInputFieldViewModel: InputFieldViewModel {
    override func didReceive(replacement: String, in range: NSRange) -> Bool {
        let lowercased = replacement.lowercased()
        let result = super.didReceive(replacement: lowercased, in: range)
        return result && lowercased == replacement
    }
}
