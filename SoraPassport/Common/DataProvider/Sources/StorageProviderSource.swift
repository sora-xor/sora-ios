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
import FearlessUtils

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

    init(itemIdentifier: String,
         codingPath: StorageCodingPath,
         runtimeService: RuntimeCodingServiceProtocol,
         provider: StreamableProvider<ChainStorageItem>,
         trigger: DataProviderTriggerProtocol) {
        self.itemIdentifier = itemIdentifier
        self.codingPath = codingPath
        self.runtimeService = runtimeService
        self.provider = provider
        self.trigger = trigger

        subscribe()
    }

    // MARK: Private

    private func replaceAndNotifyIfNeeded(_ newItem: ChainStorageItem?) {
        if newItem != lastSeenResult || lastSeenError != nil {
            lock.lock()

            lastSeenError = nil
            lastSeenResult = newItem

            lock.unlock()

            trigger.delegate?.didTrigger()
        }
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
            let finalItem: ChainStorageItem? = changes.reduce(nil) { (_, item) in
                switch item {
                case .insert(let newItem), .update(let newItem):
                    return newItem
                case .delete:
                    return nil
                }
            }

            self?.replaceAndNotifyIfNeeded(finalItem)
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
                             deliverOn: DispatchQueue.global(qos: .default),
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
