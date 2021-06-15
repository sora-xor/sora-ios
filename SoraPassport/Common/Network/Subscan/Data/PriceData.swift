/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct PriceData: Codable, Equatable {
    let price: String
    let time: Int64
    let height: Int64
    let records: [PriceRecord]
}

struct PriceRecord: Codable, Equatable {
    let price: String
    let time: Int64
    let height: Int64
}
