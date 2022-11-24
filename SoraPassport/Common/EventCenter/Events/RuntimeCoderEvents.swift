/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct RuntimeCoderCreated: EventProtocol {
    let chainId: ChainModel.Id

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeCoderReady(event: self)
    }
}

struct RuntimeCoderCreationFailed: EventProtocol {
    let chainId: ChainModel.Id
    let error: Error

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeCoderCreationFailed(event: self)
    }
}
