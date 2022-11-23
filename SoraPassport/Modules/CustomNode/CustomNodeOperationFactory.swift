/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/


import Foundation
import FearlessUtils
import RobinHood

protocol CustomNodeOperationFactoryProtocol {
    func createGetGenesisBlockOperation() -> BaseOperation<String>
}

final class CustomNodeOperationFactory {

    private let url: URL

    init(url: URL) {
        self.url = url
    }
}

extension CustomNodeOperationFactory: CustomNodeOperationFactoryProtocol {
    func createGetGenesisBlockOperation() -> BaseOperation<String> {
        let engine = WebSocketEngine(url: url)

        var currentBlock = 0
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(engine: engine,
                                            method: RPCMethod.getBlockHash,
                                            parameters: [param])
    }
}
