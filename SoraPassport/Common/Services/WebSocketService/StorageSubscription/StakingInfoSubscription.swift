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
import SSFStorageQueryKit

final class StakingInfoSubscription: WebSocketSubscribing {
    let engine: JSONRPCEngine
    let logger: LoggerProtocol
    let stashId: Data
    let storage: AnyDataProviderRepository<ChainStorageItem>
    let localStorageIdFactory: ChainStorageIdFactoryProtocol
    let operationManager: OperationManagerProtocol
    let eventCenter: EventCenterProtocol

    var controllerId: Data? {
        didSet {
            if controllerId != oldValue {
                unsubscribe()
                subscribe()
            }
        }
    }

    private var subscriptionId: UInt16?

    init(engine: JSONRPCEngine,
         stashId: Data,
         storage: AnyDataProviderRepository<ChainStorageItem>,
         localStorageIdFactory: ChainStorageIdFactoryProtocol,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol,
         logger: LoggerProtocol) {
        self.engine = engine
        self.stashId = stashId
        self.storage = storage
        self.localStorageIdFactory = localStorageIdFactory
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.logger = logger

        subscribe()
    }

    deinit {
        unsubscribe()
    }

    private func subscribe() {
        do {
            guard let controllerId = controllerId else {
                return
            }

            let storageKey = try StorageKeyFactory()
                .stakingInfoForControllerId(controllerId)
                .toHex(includePrefix: true)

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = {
                [weak self] (update) in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] (error, unsubscribed) in
                self?.logger.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            subscriptionId = try engine.subscribe(RPCMethod.storageSubscribe,
                                                  params: [[storageKey]],
                                                  updateClosure: updateClosure,
                                                  failureClosure: failureClosure)
        } catch {
            logger.error("Can't subscribe to storage: \(error)")
        }
    }

    private func unsubscribe() {
        if let identifier = subscriptionId {
            engine.cancelForIdentifier(identifier)
        }
    }

    private func handleUpdate(_ update: StorageUpdate) {
        do {
            let updateData = StorageUpdateData(update: update)

            guard let change = updateData.changes.first else {
                logger.warning("No updates found for staking")
                return
            }

            // save by stash id to avoid intermediate call to controller
            let storageKey = try StorageKeyFactory().stakingInfoForControllerId(stashId)

            let identifier = try localStorageIdFactory.createIdentifier(for: storageKey)

            let fetchOperation = storage.fetchOperation(by: identifier,
                                                        options: RepositoryFetchOptions())

            let processingOperation: BaseOperation<DataProviderChange<ChainStorageItem>?> =
                ClosureOperation {
                let newItem: ChainStorageItem?

                if let newData = change.value {
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

                self?.handle(result: changeResult)
            }

            operationManager.enqueue(operations: [fetchOperation, processingOperation, saveOperation],
                                     in: .sync)

            logger.debug("Did receive staking ledger update")
        } catch {
            logger.error("Did receive staking updates error: \(error)")
        }
    }

    private func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>) {
        if case .success(let optionalChange) = result, optionalChange != nil {
            DispatchQueue.main.async {
                self.eventCenter.notify(with: WalletStakingInfoChanged())
            }
        }
    }
}
