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

        saveOperation.completionBlock = { [weak self, weak saveOperation] in
            guard let self else { return }
            guard let saveResult = saveOperation?.result else {
                self.handle(result: .failure(BaseOperationError.parentOperationCancelled), blockHash: blockHash)
                return
            }
            if case let .failure(error) = saveResult {
                self.handle(result: .failure(error), blockHash: blockHash)
                return
            }
            guard let changeResult = processingOperation.result else { return }
            self.handle(result: changeResult, blockHash: blockHash)
        }

        operationManager.enqueue(operations: [fetchOperation, processingOperation, saveOperation],
                                 in: .sync)
    }
}
