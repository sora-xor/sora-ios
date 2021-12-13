/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto

extension IRPublicKeyProtocol {
    var decentralizedUsername: String {
        return String(rawData().soraHex.prefix(20))
    }
}
