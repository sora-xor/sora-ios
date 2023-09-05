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

class BaseStorageChildSubscription: StorageChildSubscribing {
    let remoteStorageKey: Data
    let localStorageKey: String
    let logger: LoggerProtocol
    let storage: AnyDataProviderRepository<ChainStorageItem>
    let operationManager: OperationManagerProtocol

    init(remoteStorageKey: Data,
         localStorageKey: String,
         storage: AnyDataProviderRepository<ChainStorageItem>,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.remoteStorageKey = remoteStorageKey
        self.localStorageKey = localStorageKey
        self.storage = storage
        self.operationManager = operationManager
        self.logger = logger
    }

    func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash: Data?) {
        logger.warning("Must be overriden after inheritance")
    }

    func processUpdate(_ data: Data?, blockHash: Data?) {
        let identifier = localStorageKey

        let fetchOperation = storage.fetchOperation(by: identifier,
                                                    options: RepositoryFetchOptions())

        let processingOperation: BaseOperation<DataProviderChange<ChainStorageItem>?> =
            ClosureOperation {
            let newItem: ChainStorageItem?

            if let newData = data {
                newItem = ChainStorageItem(identifier: identifier, data: newData)
            } else {
                newItem = nil
            }

            let currentItem = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return DataProviderChange<ChainStorageItem>
                .change(value1: currentItem, value2: newItem)
        }

        let saveOperation = storage.saveOperation({
            guard let update = try processingOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                return []
            }

            if let item = update.item {
                return [item]
            } else {
                return []
            }
        }, {
            guard let update = try processingOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                return []
            }

            if case .delete(let identifier) = update {
                return [identifier]
            } else {
                return []
            }
        })

        processingOperation.addDependency(fetchOperation)
        saveOperation.addDependency(processingOperation)

        saveOperation.completionBlock = { [weak self] in
            guard let changeResult = processingOperation.result else {
                return
            }

            self?.handle(result: changeResult, blockHash: blockHash)
        }

        operationManager.enqueue(operations: [fetchOperation, processingOperation, saveOperation],
                                 in: .sync)
    }
}
