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
import SSFUtils
import SSFUtils

protocol RuntimeProviderProtocol: AnyObject, RuntimeCodingServiceProtocol {
    var chainId: ChainModel.Id { get }
    var snapshot: RuntimeSnapshot? { get }

    func setup()
    func setupHot()
    func replaceTypesUsage(_ newTypeUsage: ChainModel.TypesUsage)
    func cleanup()
    func fetchCoderFactoryOperation(
        with timeout: TimeInterval,
        closure: RuntimeMetadataClosure?
    ) -> BaseOperation<RuntimeCoderFactoryProtocol>
}

enum RuntimeProviderError: Error {
    case providerUnavailable
}

final class RuntimeProvider {
    struct PendingRequest {
        let resultClosure: (RuntimeCoderFactoryProtocol?) -> Void
        let queue: DispatchQueue?
    }

    internal let chainId: ChainModel.Id
    private(set) var typesUsage: ChainModel.TypesUsage

    private let snapshotOperationFactory: RuntimeSnapshotFactoryProtocol
    private let snapshotHotOperationFactory: RuntimeHotBootSnapshotFactoryProtocol?
    private let eventCenter: EventCenterProtocol
    private let operationQueue: OperationQueue
    private let dataHasher: StorageHasher
    private let logger: LoggerProtocol?
    private let repository: AnyDataProviderRepository<RuntimeMetadataItem>

    private(set) var snapshot: RuntimeSnapshot?
    private(set) var pendingRequests: [PendingRequest] = []
    private(set) var currentWrapper: CompoundOperationWrapper<RuntimeSnapshot?>?
    private var mutex = NSLock()

    private var commonTypesFetched: Bool = false
    private var chainTypesFetched: Bool = false
    private var chainMetadataFetched: Bool = false

    init(
        chainModel: ChainModel,
        snapshotOperationFactory: RuntimeSnapshotFactoryProtocol,
        snapshotHotOperationFactory: RuntimeHotBootSnapshotFactoryProtocol?,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        dataHasher: StorageHasher = .twox256,
        logger: LoggerProtocol? = nil,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>
    ) {
        chainId = chainModel.chainId
        typesUsage = chainModel.typesUsage
        self.snapshotOperationFactory = snapshotOperationFactory
        self.snapshotHotOperationFactory = snapshotHotOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.dataHasher = dataHasher
        self.logger = logger
        self.repository = repository
        commonTypesFetched = typesUsage == .onlyOwn

        eventCenter.add(observer: self, dispatchIn: DispatchQueue.global())
    }

    private func buildSnapshot(with typesUsage: ChainModel.TypesUsage, dataHasher: StorageHasher) {
        guard commonTypesFetched, chainTypesFetched, chainMetadataFetched else {
            return
        }

        let wrapper = snapshotOperationFactory.createRuntimeSnapshotWrapper(
            for: typesUsage,
            dataHasher: dataHasher
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.handleCompletion(result: wrapper.targetOperation.result)
            }
        }

        currentWrapper = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func buildHotSnapshot(with typesUsage: ChainModel.TypesUsage, dataHasher: StorageHasher) {
        let wrapper = snapshotHotOperationFactory?.createRuntimeSnapshotWrapper(
            for: typesUsage,
            dataHasher: dataHasher
        )

        wrapper?.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.handleCompletion(result: wrapper?.targetOperation.result)
            }
        }

        currentWrapper = wrapper

        operationQueue.addOperations(wrapper?.allOperations ?? [], waitUntilFinished: false)
    }

    private func handleCompletion(result: Result<RuntimeSnapshot?, Error>?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        switch result {
        case let .success(snapshot):
            currentWrapper = nil

            if let snapshot = snapshot {
                self.snapshot = snapshot
                updateMetadata(snapshot)

                logger?.debug("Did complete snapshot for: \(chainId)")
                logger?.debug("Will notify waiters: \(pendingRequests.count)")

                resolveRequests()

                let event = RuntimeCoderCreated(chainId: chainId)
                eventCenter.notify(with: event)
            }
        case let .failure(error):
            currentWrapper = nil

            logger?.debug("Failed to build snapshot for \(chainId): \(error)")

            let event = RuntimeCoderCreationFailed(chainId: chainId, error: error)
            eventCenter.notify(with: event)
        case .none:
            break
        }
    }

    private func updateMetadata(_ snapshot: RuntimeSnapshot) {
        let localMetadataOperation = repository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        let updateOperation = repository.saveOperation {
            guard
                let currentRuntimeItem = try localMetadataOperation.extractNoCancellableResultData(),
                currentRuntimeItem.resolver != snapshot.metadata.schemaResolver
            else {
                return []
            }
            var updateItem: [RuntimeMetadataItem] = []

            let metadataItem = RuntimeMetadataItem(
                chain: currentRuntimeItem.chain,
                version: currentRuntimeItem.version,
                txVersion: currentRuntimeItem.txVersion,
                metadata: currentRuntimeItem.metadata,
                resolver: snapshot.metadata.schemaResolver
            )

            updateItem = [metadataItem]

            return updateItem
        } _: {
            []
        }

        updateOperation.addDependency(localMetadataOperation)
        operationQueue.addOperations([localMetadataOperation, updateOperation], waitUntilFinished: false)
    }

    private func resolveRequests() {
        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach { deliver(snapshot: snapshot, to: $0) }
    }

    private func deliver(snapshot: RuntimeSnapshot?, to request: PendingRequest) {
        let coderFactory = snapshot.map {
            RuntimeCoderFactory(
                catalog: $0.typeRegistryCatalog,
                specVersion: $0.specVersion,
                txVersion: $0.txVersion,
                metadata: $0.metadata
            )
        }

        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(coderFactory)
        }
    }

    private func fetchCoderFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (RuntimeCoderFactoryProtocol?) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests.append(request)
        }
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { [weak self] in
            guard let self = self else {
                throw RuntimeProviderError.providerUnavailable
            }

            var fetchedFactory: RuntimeCoderFactoryProtocol?

            let semaphore = DispatchSemaphore(value: 0)

            let queue = DispatchQueue(label: "jp.co.soramitsu.fearless.fetchCoder.\(self.chainId)", qos: .utility)
            self.fetchCoderFactory(runCompletionIn: queue) { factory in
                fetchedFactory = factory
                semaphore.signal()
            }

            semaphore.wait()

            guard let factory = fetchedFactory else {
                throw RuntimeProviderError.providerUnavailable
            }

            return factory
        }
    }

    func fetchCoderFactoryOperation(
        with _: TimeInterval,
        closure _: RuntimeMetadataClosure?
    ) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        AwaitOperation { [weak self] in
            try await withCheckedThrowingContinuation { continuation in
                self?.fetchCoderFactory(runCompletionIn: nil) { factory in
                    guard let factory = factory else {
                        continuation.resume(with: .failure(RuntimeProviderError.providerUnavailable))
                        return
                    }

                    continuation.resume(with: .success(factory))
                }
            }
        }
    }
}

extension RuntimeProvider: RuntimeProviderProtocol {
    func setupHot() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard currentWrapper == nil else {
            return
        }

        buildHotSnapshot(with: typesUsage, dataHasher: dataHasher)
    }

    var runtimeSnapshot: RuntimeSnapshot? {
        snapshot
    }

    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard currentWrapper == nil else {
            return
        }

        buildSnapshot(with: typesUsage, dataHasher: dataHasher)
    }

    func replaceTypesUsage(_ newTypeUsage: ChainModel.TypesUsage) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard typesUsage != newTypeUsage else {
            return
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        typesUsage = newTypeUsage

        buildSnapshot(with: newTypeUsage, dataHasher: dataHasher)
    }

    func cleanup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        snapshot = nil

        currentWrapper?.cancel()
        currentWrapper = nil

        resolveRequests()
    }
}

extension RuntimeProvider: EventVisitorProtocol {
    func processRuntimeChainTypesSyncCompleted(event: RuntimeChainTypesSyncCompleted) {
        guard event.chainId == chainId else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard snapshot?.localChainHash != event.fileHash else {
            return
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        logger?.debug("Will start building snapshot after chain types update for \(chainId)")

        chainTypesFetched = true

        buildSnapshot(with: typesUsage, dataHasher: dataHasher)
    }

    func processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted) {
        guard event.chainId == chainId else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        logger?.debug("Will start building snapshot after metadata update for \(chainId)")

        chainMetadataFetched = true

        buildSnapshot(with: typesUsage, dataHasher: dataHasher)
    }

    func processRuntimeCommonTypesSyncCompleted(event: RuntimeCommonTypesSyncCompleted) {
        guard typesUsage != .onlyOwn else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard snapshot?.localCommonHash != event.fileHash else {
            return
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        logger?.debug("Will start building snapshot after common types update for \(chainId)")

        commonTypesFetched = true

        buildSnapshot(with: typesUsage, dataHasher: dataHasher)
    }
}
