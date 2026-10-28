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
        let id = UUID()
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
    private var currentBuildID: UUID?

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
        typesUsage = ReviewedSoraRuntimeSnapshotAdmission
            .isReviewedSoraChain(chainModel.chainId)
            ? .onlyOwn
            : chainModel.typesUsage
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

    deinit {
        cleanup()
        eventCenter.remove(observer: self)
    }

    private func buildSnapshot(with typesUsage: ChainModel.TypesUsage, dataHasher: StorageHasher) {
        guard commonTypesFetched, chainTypesFetched, chainMetadataFetched else {
            return
        }

        let wrapper = snapshotOperationFactory.createRuntimeSnapshotWrapper(
            for: typesUsage,
            dataHasher: dataHasher
        )

        let buildID = UUID()
        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.handleCompletion(result: wrapper.targetOperation.result, buildID: buildID)
            }
        }

        currentBuildID = buildID
        currentWrapper = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func buildHotSnapshot(with typesUsage: ChainModel.TypesUsage, dataHasher: StorageHasher) {
        guard let wrapper = snapshotHotOperationFactory?.createRuntimeSnapshotWrapper(
            for: typesUsage,
            dataHasher: dataHasher
        ) else { return }

        let buildID = UUID()
        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.handleCompletion(result: wrapper.targetOperation.result, buildID: buildID)
            }
        }

        currentBuildID = buildID
        currentWrapper = wrapper
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func handleCompletion(result: Result<RuntimeSnapshot?, Error>?, buildID: UUID) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard currentBuildID == buildID else { return }
        currentBuildID = nil
        currentWrapper = nil

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
            } else {
                resolveRequests()
            }
        case let .failure(error):
            currentWrapper = nil

            logger?.debug("Runtime snapshot build failed")
            resolveRequests()

            let event = RuntimeCoderCreationFailed(chainId: chainId, error: error)
            eventCenter.notify(with: event)
        case .none:
            resolveRequests()
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
        timeout: TimeInterval? = nil,
        executing closure: @escaping (RuntimeCoderFactoryProtocol?) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else if let timeout, !timeout.isFinite || timeout <= 0 {
            deliver(snapshot: nil, to: request)
        } else {
            pendingRequests.append(request)
            if let timeout {
                let requestID = request.id
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { [weak self] in
                    self?.expireRequest(requestID)
                }
            }
        }
    }

    private func expireRequest(_ id: UUID) {
        mutex.lock()
        guard let index = pendingRequests.firstIndex(where: { $0.id == id }) else {
            mutex.unlock()
            return
        }
        let request = pendingRequests.remove(at: index)
        mutex.unlock()
        deliver(snapshot: nil, to: request)
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { [weak self] in
            guard let self = self else {
                throw RuntimeProviderError.providerUnavailable
            }

            var fetchedFactory: RuntimeCoderFactoryProtocol?

            let semaphore = DispatchSemaphore(value: 0)

            self.fetchCoderFactory(runCompletionIn: nil) { factory in
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
        with timeout: TimeInterval,
        closure _: RuntimeMetadataClosure?
    ) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        AwaitOperation { [weak self] in
            try await withCheckedThrowingContinuation { continuation in
                guard let self else {
                    continuation.resume(throwing: RuntimeProviderError.providerUnavailable)
                    return
                }
                self.fetchCoderFactory(runCompletionIn: nil, timeout: timeout) { factory in
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

        let admittedUsage: ChainModel.TypesUsage =
            ReviewedSoraRuntimeSnapshotAdmission
                .isReviewedSoraChain(chainId)
            ? .onlyOwn
            : newTypeUsage
        guard typesUsage != admittedUsage else {
            return
        }

        currentBuildID = nil
        currentWrapper?.cancel()
        currentWrapper = nil

        typesUsage = admittedUsage

        buildSnapshot(with: admittedUsage, dataHasher: dataHasher)
    }

    func cleanup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        snapshot = nil

        currentBuildID = nil
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

        currentBuildID = nil
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

        currentBuildID = nil
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

        currentBuildID = nil
        currentWrapper?.cancel()
        currentWrapper = nil

        logger?.debug("Will start building snapshot after common types update for \(chainId)")

        commonTypesFetched = true

        buildSnapshot(with: typesUsage, dataHasher: dataHasher)
    }
}
