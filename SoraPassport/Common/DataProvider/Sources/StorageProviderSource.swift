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
import SSFUtils

final class StorageProviderSource<T: Decodable & Equatable>: DataProviderSourceProtocol {
    typealias Model = ChainStorageDecodedItem<T>

    let itemIdentifier: String
    let codingPath: StorageCodingPath
    let runtimeService: RuntimeCodingServiceProtocol
    let provider: StreamableProvider<ChainStorageItem>
    let trigger: DataProviderTriggerProtocol

    private var lastSeenResult: ChainStorageItem?
    private var lastSeenError: Error?

    private var lock = NSLock()
    private let observerQueue: DispatchQueue

    init(itemIdentifier: String,
         codingPath: StorageCodingPath,
         runtimeService: RuntimeCodingServiceProtocol,
         provider: StreamableProvider<ChainStorageItem>,
         trigger: DataProviderTriggerProtocol,
         observerQueue: DispatchQueue = DispatchQueue(label: "jp.co.soramitsu.storageprovider.observer", qos: .default)) {
        self.itemIdentifier = itemIdentifier
        self.codingPath = codingPath
        self.runtimeService = runtimeService
        self.provider = provider
        self.trigger = trigger
        self.observerQueue = observerQueue

        subscribe()
    }

    // MARK: Private

    private func replaceAndNotifyIfNeeded(_ newItem: ChainStorageItem?) {
        lock.lock()
        let changed = newItem != lastSeenResult || lastSeenError != nil
        if changed {
            lastSeenError = nil
            lastSeenResult = newItem
        }
        lock.unlock()
        if changed { trigger.delegate?.didTrigger() }
    }

    private func replaceAndNotifyError(_ error: Error) {
        lock.lock()

        lastSeenResult = nil
        lastSeenError = error

        lock.unlock()

        trigger.delegate?.didTrigger()
    }

    private func subscribe() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<ChainStorageItem>]) in
            guard let self else { return }
            // A shared provider can emit other keys or an empty refresh batch.
            // Only the final change for this storage key replaces its value.
            guard let change = changes.last(where: { change in
                switch change {
                case .insert(let item), .update(let item): return item.identifier == self.itemIdentifier
                case .delete(let identifier): return identifier == self.itemIdentifier
                }
            }) else { return }
            switch change {
            case .insert(let item), .update(let item): self.replaceAndNotifyIfNeeded(item)
            case .delete: self.replaceAndNotifyIfNeeded(nil)
            }
        }

        let failure = { [weak self] (error: Error) in
            self?.replaceAndNotifyError(error)
            return
        }

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: 0,
                                                        refreshWhenEmpty: false)
        provider.addObserver(self,
                             deliverOn: observerQueue,
                             executing: updateClosure,
                             failing: failure,
                             options: options)
    }

    private func prepareBaseOperation() -> CompoundOperationWrapper<T?> {
        if let error = lastSeenError {
            return CompoundOperationWrapper<T?>.createWithError(error)
        }

        guard let data = lastSeenResult?.data else {
            return CompoundOperationWrapper<T?>.createWithResult(nil)
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let decodingOperation = StorageDecodingOperation<T>(path: codingPath, data: data)
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        let mappingOperation: BaseOperation<T?> = ClosureOperation {
            try decodingOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation,
                                        dependencies: [codingFactoryOperation, decodingOperation])
    }
}

extension StorageProviderSource {
    func fetchOperation(by modelId: String) -> CompoundOperationWrapper<Model?> {
        lock.lock()

        defer {
            lock.unlock()
        }

        guard modelId == itemIdentifier else {
            return CompoundOperationWrapper<Model?>.createWithResult(nil)
        }

        let baseOperationWrapper = prepareBaseOperation()
        let mappingOperation: BaseOperation<Model?> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return ChainStorageDecodedItem(identifier: modelId, item: item)
            } else {
                return nil
            }
        }

        let dependencies = baseOperationWrapper.allOperations
        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation,
                                        dependencies: dependencies)
    }

    func fetchOperation(page index: UInt) -> CompoundOperationWrapper<[Model]> {
        guard index == 0 else { return .createWithResult([]) }
        lock.lock()

        defer {
            lock.unlock()
        }

        let currentId = itemIdentifier

        let baseOperationWrapper = prepareBaseOperation()
        let mappingOperation: BaseOperation<[Model]> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return [ChainStorageDecodedItem(identifier: currentId, item: item)]
            } else {
                return []
            }
        }

        let dependencies = baseOperationWrapper.allOperations
        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation,
                                        dependencies: dependencies)
    }
}
