/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

struct ChainStorageItem: Codable, Identifiable, Equatable {
    enum CodingKeys: String, CodingKey {
        case identifier
        case data
    }

    let identifier: String
    let data: Data
}
