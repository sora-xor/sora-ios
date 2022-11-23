/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct RuntimeCommonTypesSyncCompleted: EventProtocol {
    let fileHash: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeCommonTypesSyncCompleted(event: self)
    }
}

struct RuntimeChainTypesSyncCompleted: EventProtocol {
    let chainId: ChainModel.Id
    let fileHash: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeChainTypesSyncCompleted(event: self)
    }
}

struct RuntimeMetadataSyncCompleted: EventProtocol {
    let chainId: ChainModel.Id
    let version: RuntimeVersion

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeChainMetadataSyncCompleted(event: self)
    }
}
