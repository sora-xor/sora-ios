/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class PersonalInfoCodeViewModel: PersonalInfoViewModel {
    override func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool {
        let lowercased = string.lowercased()
        let result = super.didReceiveReplacement(lowercased, for: range)
        return result && lowercased == string
    }
}
