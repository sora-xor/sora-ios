import Foundation
import RobinHood
import SSFAssetManagment
import SSFLogger
import SSFModels
import SSFNetwork
import SSFUtils

public protocol ChainsDataFetcherProtocol {
    func getChainModel(for chainId: ChainModel.Id) async throws -> ChainModel
    func getChainModels() async throws -> [ChainModel]
    func syncUp()
}

public enum ChainsDataFetcherError: Error {
    case chainsNotLoaded
    case missingChainModel
    case invalidUrl
    case mappingError
}

public final class ChainsDataFetcher {
    private let chainsUrl: URL
    private let dataFetchFactory: NetworkOperationFactoryProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let operationQueue: OperationQueue
    private let localeChainService: LocalChainModelService

    private lazy var scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())
    private var retryAttempt: Int = 0
    private var isSyncing: Bool = false
    private let mutex = NSLock()

    private var remoteMapping: [ChainModel.Id: ChainModel] = [:]

    public init(
        chainsUrl: URL,
        operationQueue: OperationQueue,
        dataFetchFactory: NetworkOperationFactoryProtocol,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        localeChainService: LocalChainModelService
    ) {
        self.chainsUrl = chainsUrl
        self.dataFetchFactory = dataFetchFactory
        self.operationQueue = operationQueue
        self.retryStrategy = retryStrategy
        self.localeChainService = localeChainService
    }

    private func executeSync() async throws -> [ChainModel.Id: ChainModel] {
        retryAttempt += 1
        let chainsMap = try await fetchRemoteData(chainsUrl: chainsUrl)
        return chainsMap
    }

    private func syncChanges(remoteChains: [ChainModel]) -> [ChainModel.Id: ChainModel] {
        let remoteMapping = remoteChains
            .reduce(into: [ChainModel.Id: ChainModel]()) { mapping, item in
                mapping[item.chainId] = item
            }
        complete(result: .success(remoteMapping))
        return remoteMapping
    }

    private func fetchRemoteData(chainsUrl: URL) async throws -> [ChainModel.Id: ChainModel] {
        let remoteFetchChainsOperation: BaseOperation<[ChainModel]> = dataFetchFactory
            .fetchData(from: chainsUrl)

        operationQueue.addOperations([remoteFetchChainsOperation], waitUntilFinished: false)

        return try await withUnsafeThrowingContinuation { continuation in
            remoteFetchChainsOperation.completionBlock = { [weak self] in
                guard let strongSelf = self,
                      let result = remoteFetchChainsOperation.result else
                {
                    return
                }

                switch result {
                case let .success(chains):
                    let map = strongSelf.syncChanges(remoteChains: chains)
                    return continuation.resume(returning: map)
                case let .failure(error):
                    self?.complete(result: .failure(error))
                    return continuation.resume(throwing: error)
                }
            }
        }
    }

    private func complete(result: Result<[ChainModel.Id: ChainModel], Error>?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false

        switch result {
        case let .success(remoteMapping):
            retryAttempt = 0
            self.remoteMapping = remoteMapping
        case .failure, .none:
            retry()
        }
    }

    private func retry() {
        if let nextDelay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            scheduler.notifyAfter(nextDelay)
        }
    }
}

// MARK: - ChainsDataFetcherProtocol

extension ChainsDataFetcher: ChainsDataFetcherProtocol {
    public func getChainModel(for chainId: ChainModel.Id) async throws -> ChainModel {
        if let chainModel = remoteMapping[chainId] {
            return chainModel
        }

        let remoteMap = try await executeSync()
        guard let remoteChainModel = remoteMap[chainId] else {
            throw ChainsDataFetcherError.missingChainModel
        }
        return remoteChainModel
    }

    public func getChainModels() async throws -> [ChainModel] {
        if !remoteMapping.isEmpty {
            return Array(remoteMapping.values)
        }

        let remoteMap = try await executeSync()
        return Array(remoteMap.values)
    }

    public func syncUp() {
        Task { [weak self] in
            guard let self else { return }
            let chains = try await executeSync()
            try await self.syncChains(Array(chains.values))
        }
    }
}

// MARK: - SchedulerDelegate

extension ChainsDataFetcher: SchedulerDelegate {
    public func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        Task { try await executeSync() }
    }
}

private extension ChainsDataFetcher {
    func syncChains(_ chains: [ChainModel]) async throws {
        let cachedChains = try await localeChainService.getAll()

        let cachedChainsSet = Set(cachedChains.map { $0.chainId })
        let remoteChainsSet = Set(chains.map { $0.chainId })
        let chainIdsToRemove = cachedChainsSet.subtracting(remoteChainsSet)

        let chainsToSync = chains.filter { chain in
            Set(cachedChains).symmetricDifference([chain]).contains(chain)
        }
        try await localeChainService.sync(
            chainModel: chainsToSync,
            deleteIds: Array(chainIdsToRemove)
        )
    }
}
