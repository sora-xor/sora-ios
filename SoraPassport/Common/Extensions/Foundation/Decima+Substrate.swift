/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import BigInt

extension Decimal {
    func toSubstrateAmountRoundingDown(precision: Int16) -> BigUInt? {
        let handler = NSDecimalNumberHandler(roundingMode: .down,
                               scale: 0,
                               raiseOnExactness: false,
                               raiseOnOverflow: false,
                               raiseOnUnderflow: false,
                               raiseOnDivideByZero: false)

        let valueString = (self as NSDecimalNumber).multiplying(byPowerOf10: precision, withBehavior: handler).stringValue
        return BigUInt(valueString)
    }
}
