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

import CoreData
import Foundation
import RobinHood
import SSFUtils
import SoraKeystore

protocol ChainSyncServiceProtocol {
    func syncUp()
}

protocol ChainStoreRepairing {
    /// Makes damaged chain rows readable again so the chain sync can overwrite them.
    func repairDamagedChainRows()
}

/// Core Data does not return a stored row whose required text is missing: it logs "missing
/// mandatory text data" and skips the row. A chain row whose name was lost to store damage
/// is therefore invisible to every fetch, yet still holds the chain id, so the chain sync
/// can neither read it nor insert the chain again (the id is unique). The chain would never
/// load. This gives such rows an empty name, below Core Data's validation, so the next fetch
/// returns them and the sync writes the real name. A row without a chain id is left alone:
/// it is never returned and does not block the chain.
final class ChainStoreRepair: ChainStoreRepairing {
    private let databaseService: CoreDataServiceProtocol
    private let logger: LoggerProtocol?

    init(databaseService: CoreDataServiceProtocol, logger: LoggerProtocol? = Logger.shared) {
        self.databaseService = databaseService
        self.logger = logger
    }

    func repairDamagedChainRows() {
        let done = DispatchSemaphore(value: 0)
        databaseService.performAsync { [logger] context, _ in
            defer { done.signal() }
            // Batch updates exist only for SQLite stores (not for the in-memory store a
            // session uses when the chain store could not be opened).
            guard let context,
                  let stores = context.persistentStoreCoordinator?.persistentStores,
                  !stores.isEmpty,
                  stores.allSatisfy({ $0.type == NSSQLiteStoreType }) else {
                return
            }
            let request = NSBatchUpdateRequest(entityName: String(describing: CDChain.self))
            request.predicate = NSPredicate(
                format: "%K != nil AND %K == nil",
                #keyPath(CDChain.chainId),
                #keyPath(CDChain.name)
            )
            request.propertiesToUpdate = [#keyPath(CDChain.name): ""]
            request.resultType = .updatedObjectIDsResultType
            do {
                let result = try context.execute(request) as? NSBatchUpdateResult
                guard let ids = result?.result as? [NSManagedObjectID], !ids.isEmpty else {
                    return
                }
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSUpdatedObjectsKey: ids],
                    into: [context]
                )
                logger?.warning("Chain store: \(ids.count) chain row(s) without a name were made readable")
            } catch {
                logger?.warning("Chain store: damaged chain rows could not be repaired now")
            }
        }
        done.wait()
    }
}

final class ChainSyncService {
    struct SyncChanges {
        let newOrUpdatedItems: [ChainModel]
        let removedItems: [ChainModel]
    }

    let typesUrl: URL?
    let assetsUrl: URL?
    let repository: AnyDataProviderRepository<ChainModel>
    let dataFetchFactory: DataOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let retryStrategy: ReconnectionStrategyProtocol
    let operationQueue: OperationQueue
    let whitelistStore: AssetWhitelistStoring
    let storeRepair: ChainStoreRepairing?
    let logger: LoggerProtocol?

    private(set) var retryAttempt: Int = 0
    private(set) var isSyncing: Bool = false
    private var isSyncRequestedAgain: Bool = false
    /// True while the running sync has saved the chain and only waits for the
    /// optional whitelist request.
    private var isAwaitingWhitelist: Bool = false
    private let mutex = NSLock()

    /// The passes over the chain store run one after another: each reads the
    /// stored chain and saves what it made of it, so two passes at once could
    /// save an older answer over a newer one.
    private let passLock = NSLock()
    private weak var lastPass: Operation?

    private lazy var scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())

    init(
        typesUrl: URL?,
        assetsUrl: URL?,
        dataFetchFactory: DataOperationFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        whitelistStore: AssetWhitelistStoring = AssetWhitelistStore.shared,
        storeRepair: ChainStoreRepairing? = nil,
        logger: LoggerProtocol? = nil
    ) {
        self.typesUrl = typesUrl
        self.assetsUrl = assetsUrl
        self.dataFetchFactory = dataFetchFactory
        self.repository = repository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.retryStrategy = retryStrategy
        self.whitelistStore = whitelistStore
        self.storeRepair = storeRepair
        self.logger = logger
    }

    private func performSyncUpIfNeeded() {
        guard !isSyncing else {
            // Whoever asked has something new for the chain (the on-chain
            // asset list or the remote node list arrived), and the running
            // sync may already have read the old value.
            if isAwaitingWhitelist {
                // The running sync has saved the chain and only waits for the
                // whitelist, which can take as long as a request timeout (a
                // slow or filtered network). The new value does not wait for
                // that: it is saved now, with the last good whitelist.
                logger?.debug("Tried to sync up chains during the whitelist request; saving the chain now")
                executeSync(refreshWhitelist: false, completesSync: false)
            } else {
                isSyncRequestedAgain = true
                logger?.debug("Tried to sync up chains but already syncing; will sync again")
            }
            return
        }

        isSyncing = true
        retryAttempt += 1

        logger?.debug("Will start chain sync with attempt \(retryAttempt)")

        let event = ChainSyncDidStart()
        eventCenter.notify(with: event)

        executeSync()
    }

    /// One pass: read the stored chain, prepare it from what is known now
    /// (nodes, asset list, whitelist) and save it if it changed.
    ///
    /// - Parameters:
    ///   - remoteWhitelist: the whitelist fetched in this sync; `nil` uses the
    ///     last good one.
    ///   - refreshWhitelist: after this pass, fetch the whitelist and run a
    ///     pass with it.
    ///   - completesSync: `false` for a pass that saves a new value while the
    ///     running sync waits for the whitelist; the sync goes on after it.
    private func executeSync(
        whitelist remoteWhitelist: AssetWhitelist? = nil,
        refreshWhitelist: Bool = true,
        completesSync: Bool = true
    ) {
        let repairOperation = ClosureOperation<Void> { [storeRepair] in
            storeRepair?.repairDamagedChainRows()
        }
        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        localFetchOperation.addDependency(repairOperation)
        let processingOperation: BaseOperation<SyncChanges> = ClosureOperation {
            let localChains = try localFetchOperation.extractNoCancellableResultData()
            let chainId = Chain.sora.genesisHash()
            // The remote whitelist can be slow or down. Its outage must not
            // prevent the local chain and its working nodes from being saved,
            // and must not let unvetted assets in: until it arrives, the last
            // good list (or the bundled one) decides which assets are listed.
            let whitelist = remoteWhitelist ?? self.whitelistStore.current()
            let defaultChain = Self.preparedChain(
                chainId: chainId,
                addressPrefix: ApplicationConfig.shared.addressType,
                name: Chain.sora.rawValue,
                nodes: ConfigService.shared.config.defaultNodes,
                typesURL: self.typesUrl,
                local: localChains.first { $0.chainId == chainId },
                assets: AssetManager.networkAssets,
                whitelist: whitelist
            )

            let remoteChains: [ChainModel] = [defaultChain]

            let remoteMapping = remoteChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
                mapping[item.chainId] = item
            }

            let localMapping = localChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
                mapping[item.chainId] = item
            }

            let newOrUpdated: [ChainModel] = remoteChains.compactMap { remoteItem in
                if let localItem = localMapping[remoteItem.chainId] {
                    return localItem != remoteItem ? remoteItem : nil
                } else {
                    return remoteItem
                }
            }

            let removed = localChains.compactMap { localItem in
                remoteMapping[localItem.chainId] == nil ? localItem : nil
            }

            return SyncChanges(newOrUpdatedItems: newOrUpdated, removedItems: removed)
        }

        processingOperation.addDependency(localFetchOperation)

        let localSaveOperation = repository.saveOperation({
            let changes = try processingOperation.extractNoCancellableResultData()
            return changes.newOrUpdatedItems
        }, {
            let changes = try processingOperation.extractNoCancellableResultData()
            return changes.removedItems.map(\.identifier)
        })

        localSaveOperation.addDependency(processingOperation)

        let mapOperation: BaseOperation<SyncChanges> = ClosureOperation {
            _ = try localSaveOperation.extractNoCancellableResultData()

            return try processingOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(localSaveOperation)

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let self = self else { return }
                if !completesSync {
                    self.completeIntermediatePass(result: mapOperation.result)
                } else if refreshWhitelist, case let .success(changes) = mapOperation.result,
                          let assetsURL = self.assetsUrl {
                    // Publish usable bundled nodes before starting optional remote
                    // metadata work. A stalled endpoint cannot delay cold boot.
                    self.eventCenter.notify(with: ChainSyncDidComplete(
                        newOrUpdatedChains: changes.newOrUpdatedItems,
                        removedChains: changes.removedItems
                    ))
                    self.beginWhitelistRefresh(from: assetsURL, bootstrapResult: mapOperation.result)
                } else {
                    self.complete(result: mapOperation.result)
                }
            }
        }

        // After the pass before it, whichever thread asked for which.
        passLock.lock()
        if let lastPass {
            repairOperation.addDependency(lastPass)
        }
        lastPass = mapOperation
        operationQueue.addOperations([
            repairOperation, localFetchOperation, processingOperation, localSaveOperation, mapOperation
        ], waitUntilFinished: false)
        passLock.unlock()
    }

    private func beginWhitelistRefresh(from url: URL, bootstrapResult: Result<SyncChanges, Error>?) {
        mutex.lock()
        isAwaitingWhitelist = true
        // A request made during the pass that has just ended (it may have
        // read the old value) is served now, not after the whitelist request.
        if isSyncRequestedAgain {
            isSyncRequestedAgain = false
            executeSync(refreshWhitelist: false, completesSync: false)
        }
        mutex.unlock()

        let operation = dataFetchFactory.fetchData(from: url)
        operation.completionBlock = { [weak self] in
            guard let self = self else { return }
            self.mutex.lock()
            self.isAwaitingWhitelist = false
            self.mutex.unlock()
            if let data = try? operation.extractNoCancellableResultData(),
               let whitelist = self.whitelistStore.acceptRemote(data) {
                // Fetch the current local chain again, preserving a node choice
                // made while the optional HTTP request was in flight.
                self.executeSync(whitelist: whitelist, refreshWhitelist: false)
            } else {
                self.complete(result: bootstrapResult)
            }
        }
        operationQueue.addOperation(operation)
    }

    /// The end of a pass that saved a new value during the whitelist request.
    /// The sync it belongs to is still running, or has ended meanwhile.
    private func completeIntermediatePass(result: Result<SyncChanges, Error>?) {
        if case let .success(changes) = result {
            eventCenter.notify(with: ChainSyncDidComplete(
                newOrUpdatedChains: changes.newOrUpdatedItems,
                removedChains: changes.removedItems
            ))
            return
        }
        // The value was not saved. Ask again: after the running sync, or now.
        logger?.warning("Chain sync: a pass during the whitelist request failed; will sync again")
        mutex.lock()
        defer { mutex.unlock() }
        if isSyncing {
            isSyncRequestedAgain = true
        } else {
            if retryAttempt > 0 {
                scheduler.cancel()
            }
            performSyncUpIfNeeded()
        }
    }

    static func preparedChain(
        chainId: String,
        addressPrefix: UInt16,
        name: String,
        nodes: Set<ChainNodeModel>,
        typesURL: URL?,
        local: ChainModel?,
        assets: [AssetInfo],
        whitelist: AssetWhitelist
    ) -> ChainModel {
        let matchingLocal = local?.chainId == chainId && local?.addressPrefix == addressPrefix ? local : nil
        // One node per URL: the store has a uniqueness constraint on the node
        // URL, and the same URL can arrive under two names (bundled
        // "SORA Ministry of Finance 2" and PI's "Sora" for mof2). Saving both
        // failed every chain sync with a constraint conflict. Bundled names win.
        var nodesByURL: [URL: ChainNodeModel] = [:]
        if SoraNodeConnectionPolicy.isMainnet(chainId: chainId, addressPrefix: addressPrefix) {
            for node in SoraNodeConnectionPolicy.bundledMainnetNodes {
                nodesByURL[node.url] = node
            }
        }
        let orderedNodes = nodes.sorted {
            ($0.url.absoluteString, $0.name) < ($1.url.absoluteString, $1.name)
        }
        for node in orderedNodes where nodesByURL[node.url] == nil {
            nodesByURL[node.url] = node
        }
        // The uniqueness constraint covers custom nodes too. A user who added
        // a node in an older release that 3.9.0 now bundles (for example
        // ws.mof.sora.org when PI listed only mof2) keeps it as their custom
        // node; it is not saved a second time as a default node. Connection
        // candidates still include every bundled mainnet node.
        let customNodes = matchingLocal?.customNodes
        let customURLs = Set((customNodes ?? []).map(\.url))
        for url in customURLs {
            nodesByURL[url] = nil
        }
        var availableNodes = Set(nodesByURL.values)
        if availableNodes.isEmpty {
            availableNodes = (matchingLocal?.nodes ?? []).filter {
                !customURLs.contains($0.url)
            }
        }
        // The selected node is saved into the same row as the default or
        // custom node with its URL. Use that entry's name, so saving does not
        // rename the row (for example back to PI's "Sora" for mof2) and the
        // next sync does not see a changed chain again.
        let selectedNode = matchingLocal?.selectedNode.map { selected in
            availableNodes.first { $0.url == selected.url }
                ?? customNodes?.first { $0.url == selected.url }
                ?? selected
        }
        let chain = ChainModel(
            chainId: chainId,
            parentId: matchingLocal?.parentId,
            name: name,
            nodes: availableNodes,
            addressPrefix: addressPrefix,
            types: typesURL.map { ChainModel.TypesSettings(url: $0, overridesCommon: true) } ?? matchingLocal?.types,
            icon: matchingLocal?.icon,
            options: matchingLocal?.options,
            externalApi: matchingLocal?.externalApi,
            selectedNode: selectedNode,
            customNodes: customNodes,
            iosMinAppVersion: matchingLocal?.iosMinAppVersion
        )
        // Fail closed: on-chain names and symbols can be chosen by anyone, so an asset
        // is listed only when the whitelist admits it, including assets kept from the
        // local store (they may have been saved unfiltered by an earlier build).
        let retainedAssets = assets.isEmpty ? (matchingLocal?.assets.compactMap { $0.asset } ?? []) : assets
        let chainAssets = retainedAssets.compactMap { originalAsset -> ChainAssetModel? in
            guard whitelist.admits(assetId: originalAsset.assetId) else { return nil }
            var asset = originalAsset
            if let listed = whitelist.entry(for: asset.assetId) {
                asset.icon = listed.icon
                asset.name = listed.name
                asset.symbol = listed.symbol
            }
            asset.normalizeNativeAssetMetadata()
            return ChainAssetModel(assetId: asset.assetId, staking: nil, purchaseProviders: nil,
                                   type: .normal, asset: asset, chain: chain)
        }
        chain.assets = Set(chainAssets)
        return chain
    }

    private func complete(result: Result<SyncChanges, Error>?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false
        // A failed sync is retried below, and the retry reads everything again.
        let shouldSyncAgain = isSyncRequestedAgain
        isSyncRequestedAgain = false

        switch result {
        case let .success(changes):
            logger?.debug(
                """
                Sync completed: \(changes.newOrUpdatedItems) (new or updated),
                \(changes.removedItems) (removed)
                """
            )

            retryAttempt = 0

            let event = ChainSyncDidComplete(
                newOrUpdatedChains: changes.newOrUpdatedItems,
                removedChains: changes.removedItems
            )

            eventCenter.notify(with: event)

            if shouldSyncAgain {
                performSyncUpIfNeeded()
            }
        case let .failure(error):
            logger?.error("Chain synchronization failed")

            let event = ChainSyncDidFail(error: error)
            eventCenter.notify(with: event)

            retry()
        case .none:
            logger?.error("Sync failed with no result")

            let event = ChainSyncDidFail(error: BaseOperationError.unexpectedDependentResult)
            eventCenter.notify(with: event)

            retry()
        }
    }

    private func retry() {
        if let nextDelay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            logger?.debug("Scheduling chain sync retry after \(nextDelay)")

            scheduler.notifyAfter(nextDelay)
        }
    }
}

extension ChainSyncService: ChainSyncServiceProtocol {
    func syncUp() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if retryAttempt > 0 {
            scheduler.cancel()
        }

        performSyncUpIfNeeded()
    }
}

extension ChainSyncService: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSyncUpIfNeeded()
    }
}
