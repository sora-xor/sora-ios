/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension NSDecimalNumberHandler {
    static func walletHandler(precision: Int16) -> NSDecimalNumberHandler {
        NSDecimalNumberHandler(roundingMode: .up,
                               scale: precision,
                               raiseOnExactness: false,
                               raiseOnOverflow: true,
                               raiseOnUnderflow: true,
                               raiseOnDivideByZero: true)
    }
}
