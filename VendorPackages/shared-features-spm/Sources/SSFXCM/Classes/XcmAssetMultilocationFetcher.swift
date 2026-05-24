import Foundation
import RobinHood
import SSFModels
import SSFNetwork
import SSFUtils

// sourcery: AutoMockable
protocol XcmAssetMultilocationFetching {
    func versionedMultilocation(
        originAssetId: String,
        destChainId: ChainModel.Id
    ) async throws -> AssetMultilocation
}

final class XcmAssetMultilocationFetcher: XcmAssetMultilocationFetching {
    private let sourceUrl: URL
    private let dataFetchFactory: NetworkOperationFactoryProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let operationQueue: OperationQueue

    private lazy var scheduler = Scheduler(with: self, callbackQueue: DispatchQueue.global())
    private var locations: [RemoteAssetMultilocation]?
    private var retryAttempt = 0

    init(
        sourceUrl: URL,
        dataFetchFactory: NetworkOperationFactoryProtocol,
        retryStrategy: ReconnectionStrategyProtocol,
        operationQueue: OperationQueue
    ) {
        self.sourceUrl = sourceUrl
        self.dataFetchFactory = dataFetchFactory
        self.retryStrategy = retryStrategy
        self.operationQueue = operationQueue

        Task { try await executeSync() }
    }

    // MARK: - Public methods

    func versionedMultilocation(
        originAssetId: String,
        destChainId: ChainModel.Id
    ) async throws -> AssetMultilocation {
        guard let remoteAssetMultilocations = locations else {
            let assetMultilocations = try await executeSync()
            return try search(
                in: assetMultilocations,
                originAssetId: originAssetId,
                destChainId: destChainId
            )
        }

        return try search(
            in: remoteAssetMultilocations,
            originAssetId: originAssetId,
            destChainId: destChainId
        )
    }

    // MARK: - Private methods

    private func search(
        in assetMultilocations: [RemoteAssetMultilocation],
        originAssetId: String,
        destChainId: ChainModel.Id
    ) throws -> AssetMultilocation {
        guard let multilocation = assetMultilocations.first(where: { remoteAssetMultilocation in
            remoteAssetMultilocation.chainId == destChainId
        })?.assets.first(where: { assetMultilocation in
            assetMultilocation.id == originAssetId
        }) else {
            throw XcmError.missingAssetLocationsResult
        }

        return multilocation
    }

    @discardableResult
    private func executeSync() async throws -> [RemoteAssetMultilocation] {
        retryAttempt += 1
        return try await loadRemoteAssetLocations(from: sourceUrl)
    }

    private func loadRemoteAssetLocations(from _: URL) async throws -> [RemoteAssetMultilocation] {
        let networkOperation: BaseOperation<[RemoteAssetMultilocation]> = dataFetchFactory
            .fetchData(from: sourceUrl)
        operationQueue.addOperation(networkOperation)

        return try await withCheckedThrowingContinuation { continuation in
            networkOperation.completionBlock = { [weak self] in
                guard let strongSelf = self else { return }
                let result = networkOperation.result
                strongSelf.handle(result: result)
                switch result {
                case let .success(assetMultilocation):
                    continuation.resume(with: .success(assetMultilocation))
                case let .failure(error):
                    continuation.resume(with: .failure(error))
                case .none:
                    continuation.resume(with: .failure(XcmError.missingAssetLocationsResult))
                }
            }
        }
    }

    private func handle(result: Result<[RemoteAssetMultilocation], Error>?) {
        switch result {
        case let .success(remoteLocations):
            retryAttempt = 0
            locations = remoteLocations
        case .failure:
            handleFailure()
        case .none:
            handleFailure()
        }
    }

    private func handleFailure() {
        guard let nextDelay = retryStrategy.reconnectAfter(attempt: retryAttempt) else {
            return
        }
        scheduler.notifyAfter(nextDelay)
    }
}

// MARK: - SchedulerDelegate

extension XcmAssetMultilocationFetcher: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        Task { try await executeSync() }
    }
}
