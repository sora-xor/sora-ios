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
        logger: LoggerProtocol? = nil
    ) {
        self.typesUrl = typesUrl
        self.assetsUrl = assetsUrl
        self.dataFetchFactory = dataFetchFactory
        self.repository = repository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.retryStrategy = retryStrategy
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

    private func executeSync(whitelistData: Data? = nil, refreshWhitelist: Bool = true) {
        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let processingOperation: BaseOperation<SyncChanges> = ClosureOperation {
            let localChains = try localFetchOperation.extractNoCancellableResultData()
            let chainId = Chain.sora.genesisHash()
            // A remote whitelist is optional metadata. Its outage must not
            // prevent the local chain and its working nodes from being saved.
            let defaultChain = Self.preparedChain(
                chainId: chainId,
                addressPrefix: ApplicationConfig.shared.addressType,
                name: Chain.sora.rawValue,
                nodes: ConfigService.shared.config.defaultNodes,
                typesURL: self.typesUrl,
                local: localChains.first { $0.chainId == chainId },
                assets: AssetManager.networkAssets,
                whitelistData: whitelistData
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
               (try? JSONDecoder().decode([Whitelist].self, from: data)) != nil {
                // Fetch the current local chain again, preserving a node choice
                // made while the optional HTTP request was in flight.
                self.executeSync(whitelistData: data, refreshWhitelist: false)
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
        whitelistData: Data?
    ) -> ChainModel {
        let matchingLocal = local?.chainId == chainId && local?.addressPrefix == addressPrefix ? local : nil
        var availableNodes = nodes
        if SoraNodeConnectionPolicy.isMainnet(chainId: chainId, addressPrefix: addressPrefix) {
            availableNodes.formUnion(SoraNodeConnectionPolicy.bundledMainnetNodes)
        }
        if availableNodes.isEmpty {
            availableNodes = matchingLocal?.nodes ?? []
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
            selectedNode: matchingLocal?.selectedNode,
            customNodes: matchingLocal?.customNodes,
            iosMinAppVersion: matchingLocal?.iosMinAppVersion
        )
        let whitelist = whitelistData.flatMap { try? JSONDecoder().decode([Whitelist].self, from: $0) }
        let retainedAssets = assets.isEmpty ? (matchingLocal?.assets.compactMap { $0.asset } ?? []) : assets
        let chainAssets = retainedAssets.compactMap { originalAsset -> ChainAssetModel? in
            var asset = originalAsset
            if let whitelist = whitelist {
                guard let listed = whitelist.first(where: { $0.assetId == asset.assetId }) else { return nil }
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
