/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct HistoryInfo: Codable {
    let address: String
    let row: Int
    let page: Int
}
