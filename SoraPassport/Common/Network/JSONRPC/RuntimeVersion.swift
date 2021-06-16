/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct RuntimeVersion: Codable {
    let specVersion: UInt32
    let transactionVersion: UInt32
}
