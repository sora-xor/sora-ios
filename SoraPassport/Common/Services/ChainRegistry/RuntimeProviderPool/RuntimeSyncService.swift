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
import SSFModels

protocol RuntimeSyncServiceProtocol {
    func register(chain: ChainModel, with connection: ChainConnection)
    func unregister(chainId: ChainModel.Id)
    func apply(version: RuntimeVersion, for chainId: ChainModel.Id)
    /// Like `apply`, but re-downloads the metadata even when a copy for the
    /// same spec version is stored (used when signing found that copy differs
    /// from what the live node runs). The stored copy is replaced only after
    /// the download passes admission. A replacement that is already running
    /// or scheduled for this version is left alone, and its retries keep
    /// replacing.
    func applyReplacingCachedMetadata(
        version: RuntimeVersion,
        for chainId: ChainModel.Id
    )

    func hasChain(with chainId: ChainModel.Id) -> Bool
    func isChainSyncing(_ chainId: ChainModel.Id) -> Bool
}

enum RuntimeSyncServiceError: Error {
    case skipMetadataUnchanged
}

final class RuntimeSyncService {
    struct SyncInfo {
        let typesURL: URL?
        let connection: JSONRPCEngine
    }

    struct SyncResult {
        let chainId: ChainModel.Id
        let typesSyncResult: Result<String, Error>?
        let metadataSyncResult: Result<Void, Error>?
        let runtimeVersion: RuntimeVersion?
    }

    struct RetryAttempt {
        let chainId: ChainModel.Id
        let shouldSyncTypes: Bool
        let runtimeVersion: RuntimeVersion?
        let attempt: Int
    }

    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    let dataOperationFactory: DataOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let retryStrategy: ReconnectionStrategyProtocol
    let operationQueue: OperationQueue
    let dataHasher: StorageHasher
    let logger: LoggerProtocol?
    let liveRuntimeIdentityCache: Sora2LiveRuntimeIdentityCache
    let metadataEngine: (JSONRPCEngine) -> JSONRPCEngine

    private(set) var knownChains: [ChainModel.Id: SyncInfo] = [:]
    private(set) var syncingChains: [ChainModel.Id: CompoundOperationWrapper<SyncResult>] = [:]
    private(set) var retryAttempts: [ChainModel.Id: RetryAttempt] = [:]
    /// Runtime versions whose stored metadata must be downloaded again even
    /// though a copy for that spec version exists. Every sync of that version
    /// (first attempt, retries, `apply`) replaces until one succeeds.
    private(set) var metadataReplacements: [ChainModel.Id: RuntimeVersion] = [:]
    private var mutex = NSLock()
    private var retryScheduler: Scheduler?

    init(
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        dataOperationFactory: DataOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        maxConcurrentSyncRequests: Int = 8,
        dataHasher: StorageHasher = .twox256,
        logger: LoggerProtocol? = nil,
        liveRuntimeIdentityCache: Sora2LiveRuntimeIdentityCache = .shared,
        metadataEngine: @escaping (JSONRPCEngine) -> JSONRPCEngine = {
            Sora2BoundedHTTPJSONRPCEngine.wrapping($0)
        }
    ) {
        self.repository = repository
        self.filesOperationFactory = filesOperationFactory
        self.dataOperationFactory = dataOperationFactory
        self.retryStrategy = retryStrategy
        self.eventCenter = eventCenter
        self.dataHasher = dataHasher
        self.logger = logger
        self.liveRuntimeIdentityCache = liveRuntimeIdentityCache
        self.metadataEngine = metadataEngine

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = maxConcurrentSyncRequests
        operationQueue.qualityOfService = .userInitiated
        self.operationQueue = operationQueue
    }

    private static func isSameRuntime(
        _ lhs: RuntimeVersion?,
        _ rhs: RuntimeVersion?
    ) -> Bool {
        guard let lhs, let rhs else {
            return false
        }
        return lhs.specVersion == rhs.specVersion &&
            lhs.transactionVersion == rhs.transactionVersion
    }

    private func performSync(
        for chainId: ChainModel.Id,
        shouldSyncTypes: Bool,
        newVersion: RuntimeVersion? = nil
    ) {
        guard let syncInfo = knownChains[chainId] else {
            return
        }
        let replacingCachedMetadata = Self.isSameRuntime(
            metadataReplacements[chainId],
            newVersion
        )

        let chainTypesSyncWrapper: CompoundOperationWrapper<String>?
        if shouldSyncTypes {
            let typesDataOperation: BaseOperation<Data>?
            if ReviewedSoraRuntimeSnapshotAdmission
                .isReviewedSoraChain(chainId) {
                typesDataOperation = ClosureOperation {
                    try ReviewedSoraRuntimeSnapshotAdmission
                        .loadReviewedChainTypes()
                }
            } else {
                typesDataOperation = syncInfo.typesURL.map {
                    dataOperationFactory.fetchData(from: $0)
                }
            }
            chainTypesSyncWrapper = typesDataOperation.map {
                createChainTypesSyncOperation(
                    chainId,
                    hasher: dataHasher,
                    typesDataOperation: $0
                )
            }
        } else {
            chainTypesSyncWrapper = nil
        }

        let metadataSyncWrapper = newVersion.map {
            createMetadataSyncOperation(
                for: chainId,
                runtimeVersion: $0,
                connection: syncInfo.connection,
                replacingCachedMetadata: replacingCachedMetadata
            )
        }

        if chainTypesSyncWrapper == nil, metadataSyncWrapper == nil {
            return
        }

        let dependencies = (chainTypesSyncWrapper?.allOperations ?? []) +
            (metadataSyncWrapper?.allOperations ?? [])

        let processingOperation = ClosureOperation<SyncResult> {
            SyncResult(
                chainId: chainId,
                typesSyncResult: chainTypesSyncWrapper?.targetOperation.result,
                metadataSyncResult: metadataSyncWrapper?.targetOperation.result,
                runtimeVersion: newVersion
            )
        }

        dependencies.forEach { processingOperation.addDependency($0) }

        processingOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try processingOperation.extractNoCancellableResultData()
                    self?.processSyncResult(result)
                } catch let error as BaseOperationError where error == .parentOperationCancelled {
                    return
                } catch {
                    let result = SyncResult(
                        chainId: chainId,
                        typesSyncResult: .failure(error),
                        metadataSyncResult: .failure(error),
                        runtimeVersion: newVersion
                    )

                    self?.processSyncResult(result)
                }
            }
        }

        let wrapper = CompoundOperationWrapper(
            targetOperation: processingOperation,
            dependencies: dependencies
        )

        syncingChains[chainId] = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func processSyncResult(_ result: SyncResult) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        syncingChains[result.chainId] = nil

        if case .success = result.metadataSyncResult,
           Self.isSameRuntime(
               metadataReplacements[result.chainId],
               result.runtimeVersion
           ) {
            metadataReplacements[result.chainId] = nil
        }

        addRetryRequestIfNeeded(for: result)

        notifyCompletion(for: result)
    }

    private func addRetryRequestIfNeeded(for result: SyncResult) {
        let shouldSyncTypes: Bool

        if case .failure = result.typesSyncResult {
            shouldSyncTypes = true
        } else {
            shouldSyncTypes = false
        }

        let runtimeSyncVersion: RuntimeVersion?

        if let version = result.runtimeVersion, case .failure = result.metadataSyncResult {
            runtimeSyncVersion = version
        } else {
            runtimeSyncVersion = nil
        }

        if shouldSyncTypes || (runtimeSyncVersion != nil) {
            let nextAttempt = retryAttempts[result.chainId].map { $0.attempt + 1 } ?? 1

            let retryAttempt = RetryAttempt(
                chainId: result.chainId,
                shouldSyncTypes: shouldSyncTypes,
                runtimeVersion: runtimeSyncVersion,
                attempt: nextAttempt
            )

            retryAttempts[result.chainId] = retryAttempt

            rescheduleRetryIfNeeded()
        } else {
            retryAttempts[result.chainId] = nil
        }
    }

    private func rescheduleRetryIfNeeded() {
        guard retryScheduler == nil else {
            return
        }

        guard let maxAttempt = retryAttempts.max(by: { $0.value.attempt < $1.value.attempt })?
            .value.attempt else {
            return
        }

        if let delay = retryStrategy.reconnectAfter(attempt: maxAttempt) {
            retryScheduler = Scheduler(with: self)
            retryScheduler?.notifyAfter(delay)
        }
    }

    private func notifyCompletion(for result: SyncResult) {
        logger?.debug("Did complete sync \(result)")

        if case let .success(fileHash) = result.typesSyncResult {
            logger?.debug("Did sync chain type: \(result.chainId)")

            let event = RuntimeChainTypesSyncCompleted(chainId: result.chainId, fileHash: fileHash)
            eventCenter.notify(with: event)
        }

        if case .success = result.metadataSyncResult, let version = result.runtimeVersion {
            logger?.debug("Did sync metadata: \(result.chainId)")

            let event = RuntimeMetadataSyncCompleted(chainId: result.chainId, version: version)
            eventCenter.notify(with: event)
        }
    }

    private func createChainTypesSyncOperation(
        _ chainId: ChainModel.Id,
        hasher: StorageHasher,
        typesDataOperation: BaseOperation<Data>
    ) -> CompoundOperationWrapper<String> {
        let fileSaveWrapper = filesOperationFactory.saveChainTypesOperation(for: chainId) {
            let data = try typesDataOperation.extractNoCancellableResultData()
            try ReviewedSoraRuntimeSnapshotAdmission.validateChainTypes(
                chainId: chainId,
                data: data
            )
            return data
        }

        fileSaveWrapper.addDependency(operations: [typesDataOperation])

        let mapOperation = ClosureOperation<String> {
            _ = try fileSaveWrapper.targetOperation.extractNoCancellableResultData()
            let data = try typesDataOperation.extractNoCancellableResultData()
            try ReviewedSoraRuntimeSnapshotAdmission.validateChainTypes(
                chainId: chainId,
                data: data
            )

            return try hasher.hash(data: data).toHex()
        }

        mapOperation.addDependency(fileSaveWrapper.targetOperation)
        mapOperation.addDependency(typesDataOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [typesDataOperation] + fileSaveWrapper.allOperations
        )
    }

    private func createMetadataSyncOperation(
        for chainId: ChainModel.Id,
        runtimeVersion: RuntimeVersion,
        connection: JSONRPCEngine,
        replacingCachedMetadata: Bool = false
    ) -> CompoundOperationWrapper<Void> {
        let localMetadataOperation = repository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        let isReviewedSoraChain = ReviewedSoraRuntimeSnapshotAdmission
            .isReviewedSoraChain(chainId)
        let metadataConnection: JSONRPCEngine = isReviewedSoraChain
            ? metadataEngine(connection)
            : connection
        let proofs = liveRuntimeIdentityCache
        let remoteMetadaOperation = JSONRPCOperation<[String], String>(
            engine: metadataConnection,
            method: RPCMethod.getRuntimeMetadata
        )

        remoteMetadaOperation.configurationBlock = {
            guard !replacingCachedMetadata else {
                // The stored copy is never deleted here; it is replaced only
                // after the downloaded bytes pass admission below.
                return
            }
            do {
                let currentItem = try localMetadataOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                if let item = currentItem,
                   item.version == runtimeVersion.specVersion {
                    if ReviewedSoraRuntimeSnapshotAdmission
                        .isReviewedSoraChain(chainId) {
                        do {
                            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                                chainId: chainId,
                                item: item
                            )
                        } catch {
                            // A stale/corrupt same-version cache is never
                            // admitted, but it is also not deleted in place.
                            // Fetch the reviewed live bytes and replace it only
                            // after their full identity check below succeeds.
                            return
                        }
                    }
                    remoteMetadaOperation.result = .failure(
                        RuntimeSyncServiceError.skipMetadataUnchanged
                    )
                }
            } catch {
                remoteMetadaOperation.result = .failure(error)
            }
        }

        remoteMetadaOperation.addDependency(localMetadataOperation)

        let saveMetadataOperation = repository.saveOperation({
            let hexMetadata = try remoteMetadaOperation.extractNoCancellableResultData()
            let rawMetadata = try Data(hexStringSSF: hexMetadata)
            let metadataItem = RuntimeMetadataItem(
                chain: chainId,
                version: runtimeVersion.specVersion,
                txVersion: runtimeVersion.transactionVersion,
                metadata: rawMetadata,
                resolver: nil
            )
            try ReviewedSoraRuntimeSnapshotAdmission.validate(
                chainId: chainId,
                item: metadataItem
            )

            return [metadataItem]
        }, { [] })

        saveMetadataOperation.addDependency(remoteMetadaOperation)

        let filterOperation = ClosureOperation<Void> {
            do {
                _ = try saveMetadataOperation.extractNoCancellableResultData()
            } catch let error as RuntimeSyncServiceError where error == .skipMetadataUnchanged {
                return
            }
            // Saved bytes came from the connected node and declare exactly
            // this runtime version, so they are its live metadata. Signing
            // then needs only the node's runtime version.
            if isReviewedSoraChain,
               let hexMetadata = try? remoteMetadaOperation
                .extractNoCancellableResultData(),
               let rawMetadata = try? Data(hexStringSSF: hexMetadata) {
                proofs.recordAdmittedMetadata(
                    rawMetadata,
                    specVersion: runtimeVersion.specVersion,
                    transactionVersion: runtimeVersion.transactionVersion
                )
            }
        }

        filterOperation.addDependency(saveMetadataOperation)

        return CompoundOperationWrapper(
            targetOperation: filterOperation,
            dependencies: [localMetadataOperation, remoteMetadaOperation, saveMetadataOperation]
        )
    }

    func clearOperations(for chainId: ChainModel.Id) {
        if let existingOperation = syncingChains[chainId] {
            syncingChains[chainId] = nil
            existingOperation.cancel()
        }

        retryAttempts[chainId] = nil
    }

    /// A sync that replaces the stored metadata for `version` is running, or
    /// its retry is scheduled.
    private func isReplacing(
        _ version: RuntimeVersion,
        for chainId: ChainModel.Id
    ) -> Bool {
        guard Self.isSameRuntime(metadataReplacements[chainId], version) else {
            return false
        }
        return syncingChains[chainId] != nil ||
            Self.isSameRuntime(retryAttempts[chainId]?.runtimeVersion, version)
    }
}

extension RuntimeSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        retryScheduler = nil

        for requestKeyValue in retryAttempts where syncingChains[requestKeyValue.key] == nil {
            performSync(
                for: requestKeyValue.key,
                shouldSyncTypes: requestKeyValue.value.shouldSyncTypes,
                newVersion: requestKeyValue.value.runtimeVersion
            )
        }
    }
}

extension RuntimeSyncService: RuntimeSyncServiceProtocol {
    func register(chain: ChainModel, with connection: ChainConnection) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let syncInfo = knownChains[chain.chainId] else {
            knownChains[chain.chainId] = SyncInfo(typesURL: chain.types?.url, connection: connection)
            return
        }

        if syncInfo.typesURL != chain.types?.url {
            knownChains[chain.chainId] = SyncInfo(typesURL: chain.types?.url, connection: connection)

            performSync(for: chain.chainId, shouldSyncTypes: true)
        }
    }

    func unregister(chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearOperations(for: chainId)
        knownChains[chainId] = nil
        metadataReplacements[chainId] = nil
    }

    func apply(version: RuntimeVersion, for chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if !Self.isSameRuntime(metadataReplacements[chainId], version) {
            // A replacement requested for an earlier runtime is obsolete.
            metadataReplacements[chainId] = nil
        }

        clearOperations(for: chainId)

        performSync(for: chainId, shouldSyncTypes: true, newVersion: version)
    }

    func applyReplacingCachedMetadata(
        version: RuntimeVersion,
        for chainId: ChainModel.Id
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard knownChains[chainId] != nil else {
            return
        }

        // Signing asks again on every failed attempt. Restarting would cancel
        // the download in progress and reset the retry backoff.
        guard !isReplacing(version, for: chainId) else {
            return
        }

        metadataReplacements[chainId] = version

        clearOperations(for: chainId)

        performSync(for: chainId, shouldSyncTypes: true, newVersion: version)
    }

    func hasChain(with chainId: ChainModel.Id) -> Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return knownChains[chainId] != nil
    }

    func isChainSyncing(_ chainId: ChainModel.Id) -> Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return (syncingChains[chainId] != nil) || (retryAttempts[chainId] != nil)
    }
}
