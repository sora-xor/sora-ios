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
import SoraKeystore
import RobinHood

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

    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol

    private var assetManagerPool: [ChainModel.Id: AssetManagerProtocol] = [:]

    private var chains: [ChainModel] = []

    private(set) var runtimeVersionSubscriptions: [ChainModel.Id: SpecVersionSubscriptionProtocol] = [:]

    private let mutex = NSLock()

    private let maxAttempts = 2

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
        networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol
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
                logger?.error("Unexpected error on handling chains update: \(error)")
            }
        }
    }
    
    func subscribeToChians() {
        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { [weak self] changes in
            self?.handle(changes: changes)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Unexpected error chains listener setup: \(error)")
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
        //TODO: insert assets, not chain?
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
//TODO: why not working?
//        snapshotHotBootBuilder.startHotBoot()
        performColdBoot()
    }

    private func subscribeToChains() {
        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { [weak self] changes in
            self?.handle(changes: changes)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Unexpected error chains listener setup: \(error)")
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
        return chain?.nodes.first { $0.url == url } ?? chain?.customNodes?.first { $0.url == url }
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
            self?.logger?.error("Unexpected error chains listener setup: \(error)")
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

        let failedChain = chains.first { chain in
            return chain.nodes.first { $0.url == url } != nil ||
                chain.customNodes?.first { $0.url == url } != nil
        }

        guard let failedChain = failedChain else { return }

        guard attempt > maxAttempts else {

            let allNodes = failedChain.nodes.sorted(by: { $0.url.absoluteString < $1.url.absoluteString }) +
                (failedChain.customNodes ?? []).sorted(by: { $0.url.absoluteString < $1.url.absoluteString })

            let currentNodeIndex = Int(allNodes.firstIndex(where: { $0.url == url } ) ?? 0)
            let nextNodeIndex = currentNodeIndex + 1

            if currentNodeIndex + 1 >= allNodes.count {
                DispatchQueue.main.async {
                    self.networkStatusPresenter?.didDecideUnreachableNodesAllertPresentation()
                }
            } else {
                if nextNodeIndex < allNodes.count {
                    let currentNode = allNodes[currentNodeIndex]
                    let nextNode = allNodes[nextNodeIndex]
                    
                    let event = FailedNodeConnectionEvent(node: currentNode)
                    eventCenter.notify(with: event)
                    changeSelectedNode(from: failedChain, to: nextNode)
                }
            }
//            }
            return
        }

        guard failedChain.selectedNode == nil else { return }

        let node = failedChain.selectedNode ?? failedChain.nodes.first(where: { $0.url != url })

        if let newUrl = node?.url {
            if let connection = getConnection(for: failedChain.chainId) {
                connection.reconnect(url: newUrl)

                let event = ChainsUpdatedEvent(updatedChains: [failedChain])
                eventCenter.notify(with: event)
            }
        }
    }

    func connectionUpdated(url: URL) {
        SettingsManager.shared.lastSuccessfulUrl = url
    }

    private func changeSelectedNode(from: ChainModel, to: ChainNodeModel) {

        let updatedChain = from.replacingSelectedNode(to)

        let saveOperation = chainRepository.saveOperation {
            return [updatedChain]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            let event = ChainsUpdatedEvent(updatedChains: [updatedChain])
            self?.eventCenter.notify(with: event)
        }
        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }
}

struct FailedNodeConnectionEvent: EventProtocol {
    let node: ChainNodeModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processFailedNodeConnection(event: self)
    }
}
