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
import SoraKeystore
import RobinHood
import SSFModels

protocol ChainRegistryProtocol: AnyObject {
    var availableChainIds: Set<ChainModel.Id>? { get }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection?
    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?
    func getAssetManager(for chainId: ChainModel.Id) -> AssetManagerProtocol
    func getChain(for chainId: ChainModel.Id) -> ChainModel?
    func getActiveNode(for chainId: ChainModel.Id) -> ChainNodeModel? 
    func subscribeToChians()

    func chainsSubscribe(
        _ target: AnyObject,
        runningInQueue: DispatchQueue,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    )

    func chainsUnsubscribe(_ target: AnyObject)
    func performHotBoot()
    func performColdBoot()
    func syncUp()
    /// Asks the runtime sync service to fetch the runtime the live node runs.
    /// Does nothing while a sync for that chain is already running or queued.
    /// A request to replace the stored metadata does nothing while such a
    /// replacement is already running or scheduled for that runtime version.
    func requestRuntimeRefresh(
        for chainId: ChainModel.Id,
        liveVersion: RuntimeVersion,
        replacingCachedMetadata: Bool
    )
}

extension ChainRegistryProtocol {
    func requestRuntimeRefresh(
        for _: ChainModel.Id,
        liveVersion _: RuntimeVersion,
        replacingCachedMetadata _: Bool
    ) {}
}

final class ChainRegistry {
    private let snapshotHotBootBuilder: SnapshotHotBootBuilderProtocol
    private let runtimeProviderPool: RuntimeProviderPoolProtocol
    private let connectionPool: ConnectionPoolProtocol
    private let chainSyncService: ChainSyncServiceProtocol
    private let runtimeSyncService: RuntimeSyncServiceProtocol
    private let commonTypesSyncService: CommonTypesSyncServiceProtocol
    private let chainProvider: StreamableProvider<ChainModel>
    private let specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol
    private let processingQueue = DispatchQueue(label: "jp.co.soramitsu.chain.registry")
    private let logger: LoggerProtocol?
    private let eventCenter: EventCenterProtocol
    private let networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol?
    private let nodeDidConnect: () -> Void

    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol

    private var assetManagerPool: [ChainModel.Id: AssetManagerProtocol] = [:]

    private var chains: [ChainModel] = []

    private(set) var runtimeVersionSubscriptions: [ChainModel.Id: SpecVersionSubscriptionProtocol] = [:]

    private let mutex = NSLock()

    private let maxAttemptCount = 2
    private var nodeFailover: [ChainModel.Id: NodeConnectionFailover] = [:]

    init(
        snapshotHotBootBuilder: SnapshotHotBootBuilderProtocol,
        runtimeProviderPool: RuntimeProviderPoolProtocol,
        connectionPool: ConnectionPoolProtocol,
        chainSyncService: ChainSyncServiceProtocol,
        runtimeSyncService: RuntimeSyncServiceProtocol,
        commonTypesSyncService: CommonTypesSyncServiceProtocol,
        chainProvider: StreamableProvider<ChainModel>,
        specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol,
        logger: LoggerProtocol? = nil,
        eventCenter: EventCenterProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol,
        networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol,
        nodeDidConnect: @escaping () -> Void = { StartupNetworkCoordinator.shared.nodeDidConnect() }
    ) {
        self.snapshotHotBootBuilder = snapshotHotBootBuilder
        self.runtimeProviderPool = runtimeProviderPool
        self.connectionPool = connectionPool
        self.chainSyncService = chainSyncService
        self.runtimeSyncService = runtimeSyncService
        self.commonTypesSyncService = commonTypesSyncService
        self.chainProvider = chainProvider
        self.specVersionSubscriptionFactory = specVersionSubscriptionFactory
        self.logger = logger
        self.eventCenter = eventCenter
        self.chainRepository = chainRepository
        self.operationManager = operationManager
        self.networkStatusPresenter = networkStatusPresenter
        self.nodeDidConnect = nodeDidConnect

        connectionPool.setDelegate(self)

    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard !changes.isEmpty else {
            return
        }

        changes.forEach { change in
            do {
                switch change {
                case let .insert(newChain):
                    let connection = try connectionPool.setupConnection(for: newChain)
                    runtimeProviderPool.setupRuntimeProvider(for: newChain)

                    runtimeSyncService.register(chain: newChain, with: connection)

                    setupRuntimeVersionSubscription(for: newChain, connection: connection)
                    setupAssetManager(for: newChain)
                    chains.append(newChain)
                case let .update(updatedChain):
                    clearRuntimeSubscription(for: updatedChain.chainId)

                    let connection = try connectionPool.setupConnection(for: updatedChain)
                    runtimeProviderPool.setupRuntimeProvider(for: updatedChain)
                    setupRuntimeVersionSubscription(for: updatedChain, connection: connection)
                    setupAssetManager(for: updatedChain)
                    chains = chains.filter { $0.chainId != updatedChain.chainId }
                    chains.append(updatedChain)

                case let .delete(chainId):
                    runtimeProviderPool.destroyRuntimeProvider(for: chainId)
                    clearRuntimeSubscription(for: chainId)

                    runtimeSyncService.unregister(chainId: chainId)
                    removeAssetManager(for: chainId)
                    chains = chains.filter { $0.chainId != chainId }
                }
            } catch {
                logger?.error("Chain update handling failed")
            }
        }
    }
    
    func subscribeToChians() {
        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { [weak self] changes in
            self?.handle(changes: changes)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Chain listener setup failed: \(error)")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            refreshWhenEmpty: false
        )

        chainProvider.addObserver(
            self,
            deliverOn: DispatchQueue.global(qos: .userInitiated),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func setupAssetManager(for chain: ChainModel) {
        guard assetManagerPool[chain.chainId] == nil else {
            return
        }
        let storage: CoreDataRepository<AssetInfo, CDAssetInfo> = SubstrateDataStorageFacade.shared.createRepository()
        let operationManager = OperationManagerFacade.sharedManager
        let assetManager = AssetManager(storage: AnyDataProviderRepository(storage),
                                        chainProvider: chainProvider,
                                        chainId: chain.chainId,
                                        operationManager: operationManager)
        assetManagerPool[chain.chainId] = assetManager
    }

    private func removeAssetManager(for chain: ChainModel.Id) {
        assetManagerPool[chain] = nil
    }

    private func setupRuntimeVersionSubscription(for chain: ChainModel, connection: ChainConnection) {
        let subscription = specVersionSubscriptionFactory.createSubscription(
            for: chain.chainId,
            connection: connection
        )

        subscription.subscribe()

        runtimeVersionSubscriptions[chain.chainId] = subscription
    }

    private func clearRuntimeSubscription(for chainId: ChainModel.Id) {
        if let subscription = runtimeVersionSubscriptions[chainId] {
            subscription.unsubscribe()
        }

        runtimeVersionSubscriptions[chainId] = nil
    }

    private func syncUpServices() {
        chainSyncService.syncUp()
        commonTypesSyncService.syncUp()
    }
}

extension ChainRegistry: ChainRegistryProtocol {
    var availableChainIds: Set<ChainModel.Id>? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Set(runtimeVersionSubscriptions.keys)
    }

    func performColdBoot() {
        subscribeToChains()
        syncUpServices()
    }

    func performHotBoot() {
        performColdBoot()
    }

    private func subscribeToChains() {
        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { [weak self] changes in
            self?.handle(changes: changes)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Chain listener setup failed: \(error)")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            refreshWhenEmpty: false
        )

        chainProvider.addObserver(
            self,
            deliverOn: DispatchQueue.global(qos: .userInitiated),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func requestRuntimeRefresh(
        for chainId: ChainModel.Id,
        liveVersion: RuntimeVersion,
        replacingCachedMetadata: Bool
    ) {
        guard runtimeSyncService.hasChain(with: chainId) else {
            return
        }
        if replacingCachedMetadata {
            runtimeSyncService.applyReplacingCachedMetadata(
                version: liveVersion,
                for: chainId
            )
        } else if !runtimeSyncService.isChainSyncing(chainId) {
            runtimeSyncService.apply(version: liveVersion, for: chainId)
        }
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return connectionPool.getConnection(for: chainId)
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return runtimeProviderPool.getRuntimeProvider(for: chainId)
    }

    func getChain(for chainId: ChainModel.Id) -> ChainModel? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return chains.first { $0.chainId == chainId }
    }

    func getActiveNode(for chainId: ChainModel.Id) -> ChainNodeModel? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let chain = chains.first { $0.chainId == chainId }
        let url = connectionPool.getConnection(for: chainId)?.url
        return chain.flatMap { SoraNodeConnectionPolicy.candidates(for: $0).first { $0.url == url } }
    }

    func getAssetManager(for chainId: ChainModel.Id) -> AssetManagerProtocol {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if assetManagerPool[chainId] == nil {
            let chain = chains.first { $0.chainId == chainId }
            setupAssetManager(for: chain!)
        }
        return assetManagerPool[chainId]!
    }

    func chainsSubscribe(
        _ target: AnyObject,
        runningInQueue: DispatchQueue,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    ) {
        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { changes in
            runningInQueue.async {
                updateClosure(changes)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Chain listener setup failed: \(error)")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            refreshWhenEmpty: false
        )

        chainProvider.addObserver(
            target,
            deliverOn: processingQueue,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func chainsUnsubscribe(_ target: AnyObject) {
        chainProvider.removeObserver(target)
    }

    func syncUp() {
        syncUpServices()
    }
}

extension ChainRegistry: ConnectionPoolDelegate {

    func connectionNeedsReconnect(url: URL, attempt: Int) {
        guard attempt >= maxAttemptCount else { return }
        // Delegate notifications are asynchronous. Ignore stale failures after
        // another connection has already been selected or established.
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.mutex.lock()
            guard let chain = self.chains.first(where: {
                self.connectionPool.getConnection(for: $0.chainId)?.url == url
            }), let connection = self.connectionPool.getConnection(for: chain.chainId) else {
                self.mutex.unlock()
                return
            }
            if case .connected = connection.state {
                self.mutex.unlock()
                return
            }
            var failover = self.nodeFailover[chain.chainId] ?? NodeConnectionFailover()
            let candidates = SoraNodeConnectionPolicy.candidates(for: chain)
            let decision = failover.failed(url: url, candidates: candidates)
            self.nodeFailover[chain.chainId] = failover
            self.mutex.unlock()

            if let failedNode = candidates.first(where: { $0.url == url }) {
                self.eventCenter.notify(with: FailedNodeConnectionEvent(node: failedNode))
            }
            if let next = decision.nextNode {
                connection.disconnectIfNeeded()
                connection.reconnect(url: next.url)
                connection.connectIfNeeded()
                self.eventCenter.notify(with: ChainsUpdatedEvent(updatedChains: [chain]))
            }
            if decision.shouldPresentUnavailable {
                DispatchQueue.main.async { [weak self] in
                    self?.networkStatusPresenter?.didDecideUnreachableNodesAllertPresentation()
                }
            }
        }
    }

    func connectionUpdated(url: URL) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.mutex.lock()
            guard let chain = self.chains.first(where: {
                self.connectionPool.getConnection(for: $0.chainId)?.url == url
            }) else {
                self.mutex.unlock()
                return
            }
            let wasUnavailablePresented = self.nodeFailover[chain.chainId]?.connected() ?? false
            self.mutex.unlock()

            SettingsManager.shared.lastSuccessfulUrl = url
            if wasUnavailablePresented {
                // The status said that no node could be reached. Only a change
                // of the device's reachability took it down, so after a node
                // outage or a captive network it stayed over a working wallet.
                DispatchQueue.main.async { [weak self] in
                    self?.networkStatusPresenter?.didDecideReachableStatusPresentation()
                }
            }
            // Work that was waiting for a node (the asset list) can go on.
            // The registry's lock is not held: that work asks the registry
            // for its connection.
            self.nodeDidConnect()
        }
    }

}

struct FailedNodeConnectionEvent: EventProtocol {
    let node: ChainNodeModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processFailedNodeConnection(event: self)
    }
}
