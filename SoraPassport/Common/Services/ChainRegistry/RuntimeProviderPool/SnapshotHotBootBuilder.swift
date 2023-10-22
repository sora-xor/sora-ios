// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import RobinHood

protocol SnapshotHotBootBuilderProtocol {
    func startHotBoot()
}

final class SnapshotHotBootBuilder: SnapshotHotBootBuilderProtocol {
    private let runtimeProviderPool: RuntimeProviderPoolProtocol
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    private let runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>
    private let operationQueue: OperationQueue
    private let logger: Logger

    init(
        runtimeProviderPool: RuntimeProviderPoolProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>,
        operationQueue: OperationQueue,
        logger: Logger
    ) {
        self.runtimeProviderPool = runtimeProviderPool
        self.chainRepository = chainRepository
        self.filesOperationFactory = filesOperationFactory
        self.runtimeItemRepository = runtimeItemRepository
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func startHotBoot() {
        let baseTypesFetchOperation = filesOperationFactory.fetchCommonTypesOperation()
        let runtimeItemsOperation = runtimeItemRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let chainModelOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        let mergeOperation = ClosureOperation<MergeOperationResult> {
            let commonTypesResult = try baseTypesFetchOperation.targetOperation.extractNoCancellableResultData()
            let runtimesResult = try runtimeItemsOperation.extractNoCancellableResultData()
            let chainModelResult = try chainModelOperation.extractNoCancellableResultData()

            return MergeOperationResult(
                commonTypes: commonTypesResult,
                runtimes: runtimesResult,
                chains: chainModelResult
            )
        }

        let dependencies = baseTypesFetchOperation.allOperations + [runtimeItemsOperation] + [chainModelOperation]

        dependencies.forEach { mergeOperation.addDependency($0) }

        mergeOperation.completionBlock = { [weak self] in
            do {
                let result = try mergeOperation.extractNoCancellableResultData()
                self?.handleMergeOperation(result: result)
            } catch {
                self?.logger.error(error.localizedDescription)
            }
        }

        let compoundOperation = CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)

        operationQueue.addOperations(compoundOperation.allOperations, waitUntilFinished: false)
    }

    private func handleMergeOperation(result: SnapshotHotBootBuilder.MergeOperationResult) {
        let runtimeItemsMap = result.runtimes.reduce(
            into: [String: RuntimeMetadataItem]()
        ) { result, runtimeItem in
            result[runtimeItem.chain] = runtimeItem
        }

        result.chains.forEach { chain in
            guard let commonTypes = result.commonTypes,
                  let runtimeItem = runtimeItemsMap[chain.chainId] else {
                return
            }
            runtimeProviderPool.setupHotRuntimeProvider(
                for: chain,
                runtimeItem: runtimeItem,
                commonTypes: commonTypes
            )
        }
    }

    private struct MergeOperationResult {
        let commonTypes: Data?
        let runtimes: [RuntimeMetadataItem]
        let chains: [ChainModel]
    }
}
