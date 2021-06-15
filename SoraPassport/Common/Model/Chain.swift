/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto

typealias SNAddressType = UInt8

enum Chain: String, Codable, CaseIterable {
    case polkadot = "Polkadot"
    case sora = "Sora"
}
