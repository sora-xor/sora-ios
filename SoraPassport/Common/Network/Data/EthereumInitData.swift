/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum EthereumInitDataState: String, Codable {
    case inProgress = "INPROGRESS"
    case completed = "COMPLETED"
    case failed = "FAILED"
}

struct EthereumInitData: Codable {
    let state: EthereumInitDataState
    let address: String
    let reason: String?
}
