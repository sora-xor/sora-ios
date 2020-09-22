import Foundation
import RobinHood

final class EthereumInitSource {
    typealias Model = EthereumInit

    let operationFactory: EthereumRegistrationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let repository: AnyDataProviderRepository<EthereumInit>
    let serviceUnit: ServiceUnit
    let requestSigner: NetworkRequestModifierProtocol

    init(serviceUnit: ServiceUnit,
         operationFactory: EthereumRegistrationFactoryProtocol,
         repository: AnyDataProviderRepository<EthereumInit>,
         requestSigner: NetworkRequestModifierProtocol,
         operationManager: OperationManagerProtocol) {
        self.serviceUnit = serviceUnit
        self.operationFactory = operationFactory
        self.repository = repository
        self.requestSigner = requestSigner
        self.operationManager = operationManager
    }
}

extension EthereumInitSource: StreamableSourceProtocol {
    func refresh(runningIn queue: DispatchQueue?, commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {
        guard let service = serviceUnit.service(for: WalletServiceType.ethereumState.rawValue) else {
            if let notificationBlock = commitNotificationBlock {
                dispatchInQueueWhenPossible(queue) {
                    notificationBlock(.failure(NetworkUnitError.serviceUnavailable))
                }
            }

            return
        }

        let countOperation = repository.fetchCountOperation()

        let stateFetchOperation = operationFactory.createRegistrationStateOperation(service.serviceEndpoint)
        stateFetchOperation.requestModifier = requestSigner

        let replaceOperation = repository.replaceOperation {
            let data = try stateFetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let sidechainInit = SidechainInit(data: data)

            return [sidechainInit]
        }

        replaceOperation.addDependency(stateFetchOperation)
        replaceOperation.addDependency(countOperation)

        replaceOperation.completionBlock = {
            if let notificationBlock = commitNotificationBlock {
                guard let result = replaceOperation.result else {
                    dispatchInQueueWhenPossible(queue) {
                        notificationBlock(.failure(BaseOperationError.parentOperationCancelled))
                    }

                    return
                }

                switch result {
                case .success:
                    let count = (try? countOperation.extractResultData()) ?? 0

                    dispatchInQueueWhenPossible(queue) {
                        notificationBlock(.success(count + 1))
                    }

                case .failure(let error):
                    if let initError = error as? EthereumInitDataError, initError == .notFound {
                        let count = (try? countOperation.extractResultData()) ?? 0

                        dispatchInQueueWhenPossible(queue) {
                            notificationBlock(.success(count))
                        }

                    } else {
                        dispatchInQueueWhenPossible(queue) {
                            notificationBlock(.failure(error))
                        }
                    }
                }
            }
        }

        operationManager.enqueue(operations: [countOperation, stateFetchOperation, replaceOperation], in: .sync)
    }

    func fetchHistory(runningIn queue: DispatchQueue?,
                      commitNotificationBlock: ((Result<Int, Error>?) -> Void)?) {

        guard let notificationBlock = commitNotificationBlock else {
            return
        }

        if let queue = queue {
            queue.async {
                notificationBlock(.failure(NetworkUnitError.serviceUnavailable))
            }
        } else {
            notificationBlock(.failure(NetworkUnitError.serviceUnavailable))
        }
    }
}
