import Foundation
import RobinHood
import CoreData

class EthereumBasePoll<T: Identifiable, C: NSManagedObject>: Pollable {
    let operationFactory: EthereumOperationFactoryProtocol
    let repository: AnyDataProviderRepository<T>
    let repositoryObservable: CoreDataContextObservable<T, C>
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    var state: PollableState = .initial {
        didSet {
            delegate?.pollableDidChangeState(self, from: oldValue)
        }
    }

    private var setupOperation: Operation?
    private var pollOperations: [Operation]?

    var transactionIds: [String: String] = [:]

    weak var delegate: PollableDelegate?

    init(operationFactory: EthereumOperationFactoryProtocol,
         repository: AnyDataProviderRepository<T>,
         repositoryObservable: CoreDataContextObservable<T, C>,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.operationFactory = operationFactory
        self.repository = repository
        self.repositoryObservable = repositoryObservable
        self.operationManager = operationManager
        self.logger = logger
    }

    func setup() {
        guard state == .initial else {
            return
        }

        state = .setuping

        transactionIds.removeAll()

        repositoryObservable.addObserver(self, deliverOn: .main) { [weak self] changes in
            self?.handle(changes: changes)
        }

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())

        setupOperation = fetch

        fetch.completionBlock = {
            do {
                let items = try fetch
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    .map { DataProviderChange.insert(newItem: $0) }

                DispatchQueue.main.async {
                    if self.state == .setuping {
                        self.setupOperation = nil

                        self.state = .setup

                        self.handle(changes: items)
                    }
                }

            } catch {
                self.logger.error("Did receive error: \(error)")

                DispatchQueue.main.async {
                    if self.state == .setuping {
                        self.setupOperation = nil

                        self.state = .initial
                    }
                }
            }
        }

        operationManager.enqueue(operations: [fetch], in: .transient)
    }

    func poll() {
        guard state == .ready, pollOperations == nil else {
            return
        }

        let wrappers = transactionIds.keys.map { createPollForIdentifier($0) }

        let combiningOperation = ClosureOperation {}

        var allOperations = [Operation]()
        for wrapper in wrappers {
            wrapper.allOperations.forEach { combiningOperation.addDependency($0) }
            allOperations.append(contentsOf: wrapper.allOperations)
        }

        allOperations.append(combiningOperation)

        combiningOperation.completionBlock = {
            DispatchQueue.main.async {
                self.pollOperations = nil
            }
        }

        operationManager.enqueue(operations: allOperations, in: .transient)
    }

    func cancel() {
        state = .initial

        setupOperation?.cancel()
        setupOperation = nil

        pollOperations?.forEach { $0.cancel() }
        pollOperations = nil

        repositoryObservable.removeObserver(self)

        transactionIds.removeAll()
    }

    // MARK: Override

    func updateTransactionIdsWithChanges(_ changes: [DataProviderChange<T>]) {}

    func createPollForIdentifier(_ identifier: String) -> CompoundOperationWrapper<Void> {
        let operation = BaseOperation<Void>()
        operation.result = .failure(BaseOperationError.unexpectedDependentResult)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    // MARK: Private

    private func handle(changes: [DataProviderChange<T>]) {
        updateTransactionIdsWithChanges(changes)

        switch state {
        case .setup:
            if !transactionIds.isEmpty {
                state = .ready
            }
        case .ready:
            if transactionIds.isEmpty {
                state = .setup
            }
        default:
            break
        }
    }
}
