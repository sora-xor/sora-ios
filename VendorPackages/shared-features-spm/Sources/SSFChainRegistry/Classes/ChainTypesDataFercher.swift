import Foundation
import RobinHood
import SSFModels
import SSFNetwork
import SSFUtils

public enum ChainTypesRemoteDataFercherError: Error {
    case missingChainId
    case missingData
    case incorrectUrl
}

public protocol ChainTypesRemoteDataFercherProtocol {
    func syncUp()
    func getTypes(for chainId: ChainModel.Id) async throws -> Data
}

public final class ChainTypesRemoteDataFercher {
    private let url: URL?
    private let dataOperationFactory: NetworkOperationFactoryProtocol
    private let retryStrategy: ReconnectionStrategyProtocol
    private let operationQueue: OperationQueue

    private var isSyncing: Bool = false
    private var retryAttempt: Int = 0

    private let mutex = NSLock()

    private lazy var scheduler: Scheduler = .init(with: self, callbackQueue: DispatchQueue.global())

    private var versioningMap: [String: Data] = [:]

    public init(
        url: URL?,
        dataOperationFactory: NetworkOperationFactoryProtocol,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection()
    ) {
        self.url = url
        self.dataOperationFactory = dataOperationFactory
        self.retryStrategy = retryStrategy
        self.operationQueue = operationQueue
    }

    private func performSyncUpIfNeeded() {
        guard !isSyncing else {
            return
        }

        isSyncing = true
        Task {
            try await fetchRemoteData()
        }
    }

    private func fetchRemoteData() async throws -> [String: Data] {
        guard let url = url else {
            throw ChainTypesRemoteDataFercherError.incorrectUrl
        }

        let fetchOperation: BaseOperation<JSON> = dataOperationFactory.fetchData(from: url)
        operationQueue.addOperation(fetchOperation)

        return try await withUnsafeThrowingContinuation { continuation in
            fetchOperation.completionBlock = { [weak self] in
                guard let result = fetchOperation.result,
                      let strongSelf = self else
                {
                    self?.handleFailure(with: ChainTypesRemoteDataFercherError.missingData)
                    return
                }

                switch result {
                case let .success(json):
                    do {
                        let versioningMap = try strongSelf.handle(json: json)
                        return continuation.resume(returning: versioningMap)
                    } catch {
                        return continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    self?.handleFailure(with: error)
                    return continuation.resume(throwing: error)
                }
            }
        }
    }

    private func handle(json: JSON) throws -> [String: Data] {
        let versioningMap = try prepareVersionedJsons(from: json)
        handleCompletion(versioningMap: versioningMap)
        return versioningMap
    }

    private func prepareVersionedJsons(from json: JSON) throws -> [String: Data] {
        guard let versionedDefinitionJsons = json.arrayValue else {
            throw ChainTypesRemoteDataFercherError.missingData
        }

        return try versionedDefinitionJsons.reduce([String: Data]()) { partialResult, json in
            var partialResult = partialResult

            guard let chainId = json.chainId?.stringValue else {
                throw ChainTypesRemoteDataFercherError.missingChainId
            }

            let data = try JSONEncoder().encode(json)

            partialResult[chainId] = data
            return partialResult
        }
    }

    private func handleCompletion(versioningMap: [String: Data]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false
        retryAttempt = 0

        self.versioningMap = versioningMap
    }

    private func handleFailure(with _: Error) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isSyncing = false
        retryAttempt += 1

        if let delay = retryStrategy.reconnectAfter(attempt: retryAttempt) {
            scheduler.notifyAfter(delay)
        }
    }
}

// MARK: - SchedulerDelegate

extension ChainTypesRemoteDataFercher: SchedulerDelegate {
    public func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        performSyncUpIfNeeded()
    }
}

// MARK: - ChainTypesRemoteDataFercherProtocol

extension ChainTypesRemoteDataFercher: ChainTypesRemoteDataFercherProtocol {
    public func syncUp() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if retryAttempt > 0 {
            scheduler.cancel()
        }

        performSyncUpIfNeeded()
    }

    public func getTypes(for chainId: ChainModel.Id) async throws -> Data {
        if let types = versioningMap[chainId] {
            return types
        }

        let remoteVersioningMap = try await fetchRemoteData()
        guard let types = remoteVersioningMap[chainId] else {
            throw ChainTypesRemoteDataFercherError.missingData
        }
        return types
    }
}
