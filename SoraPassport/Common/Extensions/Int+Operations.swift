/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension Int {
    func firstDivider(from range: [Int]) -> Int? {
        range.first { self % $0 == 0 }
    }
}
