/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct Health: Codable {
    let isSyncing: Bool
    let peers: Int
    let shouldHavePeers: Bool
}
