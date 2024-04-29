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
