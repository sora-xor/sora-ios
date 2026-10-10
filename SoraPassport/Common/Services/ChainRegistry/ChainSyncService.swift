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
import SoraKeystore

protocol ChainSyncServiceProtocol {
    func syncUp()
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
    let logger: LoggerProtocol?

    private(set) var retryAttempt: Int = 0
    private(set) var isSyncing: Bool = false
    private let mutex = NSLock()

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
        self.logger = logger
    }

    private func performSyncUpIfNeeded() {
        guard !isSyncing else {
            logger?.debug("Tried to sync up chains but already syncing")
            return
        }

        isSyncing = true
        retryAttempt += 1

        logger?.debug("Will start chain sync with attempt \(retryAttempt)")

        let event = ChainSyncDidStart()
        eventCenter.notify(with: event)

        executeSync()
    }

    private func executeSync(whitelist remoteWhitelist: AssetWhitelist? = nil, refreshWhitelist: Bool = true) {
        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
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
                if refreshWhitelist, case let .success(changes) = mapOperation.result, let assetsURL = self.assetsUrl {
                    // Publish usable bundled nodes before starting optional remote
                    // metadata work. A stalled endpoint cannot delay cold boot.
                    self.eventCenter.notify(with: ChainSyncDidComplete(
                        newOrUpdatedChains: changes.newOrUpdatedItems,
                        removedChains: changes.removedItems
                    ))
                    self.refreshWhitelist(from: assetsURL, bootstrapResult: mapOperation.result)
                } else {
                    self.complete(result: mapOperation.result)
                }
            }
        }

        operationQueue.addOperations([
            localFetchOperation, processingOperation, localSaveOperation, mapOperation
        ], waitUntilFinished: false)
    }

    private func refreshWhitelist(from url: URL, bootstrapResult: Result<SyncChanges, Error>?) {
        let operation = dataFetchFactory.fetchData(from: url)
        operation.completionBlock = { [weak self] in
            guard let self = self else { return }
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
