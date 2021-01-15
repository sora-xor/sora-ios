/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto

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

    func toHex(includePrefix: Bool = false) -> String {
        (includePrefix ? "0x" : "") + (self as NSData).toHexString()
    }

    init(hexString: String) throws {
        let prefix = "0x"
        if hexString.hasPrefix(prefix) {
            let filtered = String(hexString.suffix(hexString.count - prefix.count))
            self = (try NSData(hexString: filtered)) as Data
        } else {
            self = (try NSData(hexString: hexString)) as Data
        }
    }
}
