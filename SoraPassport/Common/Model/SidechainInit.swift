/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

enum SidechainInitState: String, Codable {
    case needsRegister
    case needsUpdatePending
    case inProgress
    case completed
    case failed
}

enum SidechainId: String, Codable {
    case eth = "jp.co.sora.sidechain.eth"
}

struct SidechainInit<T: Codable>: Codable {
    let sidechainId: SidechainId
    let state: SidechainInitState
    let userInfo: T?
}

extension SidechainInit: Identifiable {
    var identifier: String {
        sidechainId.rawValue
    }
}

struct EthereumInitUserInfo: Codable {
    let address: String
    let failureReason: String?
}
