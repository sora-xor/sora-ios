/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

typealias EthereumInit = SidechainInit<EthereumInitUserInfo>

extension SidechainInitState {
    init(ethereumInitState: EthereumInitDataState) {
        switch ethereumInitState {
        case .inProgress:
            self = .inProgress
        case .completed:
            self = .completed
        case .failed:
            self = .failed
        }
    }
}

extension EthereumInit {
    init(data: EthereumInitData) {
        sidechainId = .eth
        state = SidechainInitState(ethereumInitState: data.state)
        userInfo = EthereumInitUserInfo(address: data.address, failureReason: data.reason)
    }
}
