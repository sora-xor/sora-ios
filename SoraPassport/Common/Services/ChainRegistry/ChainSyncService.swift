import Foundation
import RobinHood
import FearlessUtils
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
    let nodesUrl: URL?
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
        nodesUrl: URL?,
        assetsUrl: URL?,
        dataFetchFactory: DataOperationFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol? = nil
    ) {
        self.typesUrl = typesUrl
        self.nodesUrl = nodesUrl
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

    private func executeSync() {
        guard let typesUrl = typesUrl, let assetsUrl = assetsUrl, let nodesUrl = nodesUrl else {
            assertionFailure()
            return
        }

        let remoteFetchAssetsOperation = dataFetchFactory.fetchData(from: assetsUrl)
        let remoteFetchOperation = dataFetchFactory.fetchData(from: nodesUrl)
        let localFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let processingOperation: BaseOperation<SyncChanges> = ClosureOperation { [weak self] in
            let assets = AssetManager.networkAssets
            let assetsRemoteData = try remoteFetchAssetsOperation.extractNoCancellableResultData()
            let whiteList: [Whitelist] = try JSONDecoder().decode([Whitelist].self, from: assetsRemoteData)

            let jsonData = try remoteFetchOperation.extractNoCancellableResultData()
            let nodesResponse = try JSONDecoder().decode(NodesResponse.self, from: jsonData)

            var filteredAssets: [AssetInfo] = []

            for var asset in assets {
                if let listed = whiteList.first(where: { (list) -> Bool in
                    list.assetId == asset.assetId
                }) {
                    asset.icon = listed.icon
                    asset.name = listed.name
                    asset.symbol = listed.symbol
                    filteredAssets.append(asset)
                }
            }
            Logger.shared.info("HANDLE ASSETS \(assets.count), whitelist: \(whiteList.count), result: \(filteredAssets.count)")

            let typesSettings  = ChainModel.TypesSettings(url: typesUrl, overridesCommon: true)
            let defaultChain = ChainModel(chainId: Chain.sora.genesisHash(),
                                          name: Chain.sora.rawValue,
                                          nodes: Set(nodesResponse.nodes),
                                          addressPrefix: ApplicationConfig.shared.addressType,
                                          types: typesSettings,
                                          icon: nil,
                                          selectedNode: nil,
                                          iosMinAppVersion: nil)
            let chainAssets = filteredAssets.map {
                ChainAssetModel(assetId: $0.assetId,
                                staking: nil,
                                purchaseProviders: nil,
                                type: .normal,
                                asset: $0,
                                chain: defaultChain) }
            defaultChain.assets = Set(chainAssets)

            let remoteChains: [ChainModel] = [defaultChain]

            remoteChains.forEach { chain in
                chain.assets.forEach { chainAsset in
                    chainAsset.chain = chain
                    if let asset = filteredAssets.first(where: { asset in
                        chainAsset.assetId == asset.assetId
                    }) {
                        chainAsset.asset = asset
                    }
                }
            }

            remoteChains.forEach {
                $0.assets = $0.assets.filter { $0.asset != nil && $0.chain != nil }
            }

            let remoteMapping = remoteChains.reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
                mapping[item.chainId] = item
            }

            let localChains = try localFetchOperation.extractNoCancellableResultData()
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

        processingOperation.addDependency(remoteFetchAssetsOperation)
        processingOperation.addDependency(remoteFetchOperation)
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
                self?.complete(result: mapOperation.result)
            }
        }

        operationQueue.addOperations([
            remoteFetchAssetsOperation, remoteFetchOperation, localFetchOperation, processingOperation, localSaveOperation, mapOperation
        ], waitUntilFinished: false)
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
            logger?.error("Sync failed with error: \(error)")

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
