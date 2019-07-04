/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import IrohaCrypto
import SoraCrypto

extension IRPublicKeyProtocol {
    var decentralizedUsername: String {
        return String(rawData().toHexString().prefix(20))
    }
}
