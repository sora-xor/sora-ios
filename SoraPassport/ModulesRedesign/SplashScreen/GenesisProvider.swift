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

import SSFUtils
import RobinHood
import Foundation

protocol GenesisProviderProtocol {
    func load(completion: @escaping (String?) -> Void)
}

final class GenesisProvider: GenesisProviderProtocol {
    let engine: JSONRPCEngine
    let operationQueue = OperationQueue()

    init(engine: JSONRPCEngine) {
        self.engine = engine
    }

    func load(completion: @escaping (String?) -> Void) {
        let genesisOperation = createGenesisOperation()

        genesisOperation.completionBlock = {
            let genesis = try? genesisOperation.extractResultData()
            completion(genesis)
        }

        operationQueue.addOperations([genesisOperation], waitUntilFinished: true)
    }

    private func createGenesisOperation() -> BaseOperation<String> {
#if F_RELEASE
        return JSONRPCListOperation<String>.createWithResult(Chain.sora.genesisHash())
#else
        var currentBlock = 0
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(engine: engine,
                                            method: RPCMethod.getBlockHash,
                                            parameters: [param])
#endif
    }
}
