/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct PagedKeysRequest: Encodable {
    let key: String
    let count: UInt32
    let offset: String?

    init(key: String, count: UInt32 = 1000, offset: String? = nil) {
        self.key = key
        self.count = count
        self.offset = offset
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(key)
        try container.encode(count)

        if let offset = offset {
            try container.encode(offset)
        }
    }
}
