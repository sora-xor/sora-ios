/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension Decimal {
    func rounded(with scale: Int = 0, mode: Decimal.RoundingMode) -> Decimal {
        var rounding = self
        var rounded = Decimal()

        NSDecimalRound(&rounded, &rounding, scale, mode)

        return rounded
    }
}
