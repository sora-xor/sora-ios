// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import BigInt

extension BigUInt {
    public init?(hexString: String, radix: Int) {
        guard (2...36).contains(radix) else { return nil }
        let digits = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        guard let value = BigUInt(digits, radix: radix) else { return nil }
        self = value
    }

    static func fromHexString(_ hex: String) -> BigUInt? {
        let prefix = "0x"

        if hex.hasPrefix(prefix) {
            let filtered = String(hex.suffix(hex.count - prefix.count))
            return BigUInt(filtered, radix: 16)
        } else {
            return BigUInt(hex, radix: 16)
        }
    }
}
