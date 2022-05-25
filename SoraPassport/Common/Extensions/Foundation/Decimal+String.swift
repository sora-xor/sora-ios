/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension Decimal {
    var stringWithPointSeparator: String {
        let separator = [NSLocale.Key.decimalSeparator: "."]
        var value = self

        return NSDecimalString(&value, separator)
    }
}
