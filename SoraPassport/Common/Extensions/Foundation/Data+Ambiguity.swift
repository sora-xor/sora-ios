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
import SSFUtils
//import SoraCrypto

/**
 *  Due to the fact that multiple libraries implement the same extension
 *  we need to fix the implementation to avoid conflict during linkage.
 */

extension Data {
    var soraHex: String {
        (self as NSData).toHexString()
    }

    var soraHexWithPrefix: String {
        let hexString = soraHex
        return "0x\(hexString)"
    }

    static func sora(hex: String) throws -> Data {
        let prefix = "0x"
        if hex.hasPrefix(prefix) {
            let filtered = String(hex.suffix(hex.count - prefix.count))
            return (try NSData(hexString: filtered)) as Data
        } else {
            return (try NSData(hexString: hex)) as Data
        }
    }

    init(hex: String) throws {
        self = try Self.sora(hex: hex)
    }
}
