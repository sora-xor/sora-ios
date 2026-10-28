// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation
import SSFUtils
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
        let engine = WebSocketEngine(connectionName: nil, url: url)

        var currentBlock = 0
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(engine: engine,
                                            method: RPCMethod.getBlockHash,
                                            parameters: [param])
    }
}
