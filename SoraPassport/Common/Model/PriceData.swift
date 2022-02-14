/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct PriceData: Codable, Equatable {
    let price: String
    let usdDayChange: Decimal?
}
