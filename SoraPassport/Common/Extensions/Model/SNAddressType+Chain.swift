/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto

extension SNAddressType {
    init(chain: Chain) {
        self = chain.addressType()
    }

    var chain: Chain {
        return .sora
    }
}
