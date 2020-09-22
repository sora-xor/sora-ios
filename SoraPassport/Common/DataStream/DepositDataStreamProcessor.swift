import Foundation
import RobinHood
import CommonWallet

final class DepositDataStreamProcessor {
    enum CancellingError: Error {
        case noDeposits
    }

    let depositRepository: AnyDataProviderRepository<DepositOperationData>
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(depositRepository: AnyDataProviderRepository<DepositOperationData>,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.depositRepository = depositRepository
        self.operationManager = operationManager
        self.logger = logger
    }

    func handleDepositedEvent(_ event: DepositCompletedStreamEvent) {
        logger.debug("Will start handling deposit event: \(event.sidechainHash)")

        let wrapper = createDepositReceiveSaving(transactionHash: event.sidechainHash)

        wrapper.targetOperation.completionBlock = {
            do {
                try wrapper.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                self.logger.debug("Deposit receive successfully handled")
            } catch {
                if error is CancellingError {
                    self.logger.debug("Deposit receive handling cancelled: \(error)")
                } else {
                    self.logger.error("Deposit receive handling failed: \(error)")
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .sync)
    }

    // MARK: Private

    private func createDepositReceiveSaving(transactionHash: String) -> CompoundOperationWrapper<Void> {
        let fetchDeposit = depositRepository.fetchOperation(by: transactionHash,
                                                            options: RepositoryFetchOptions())

        let selectDeposit = ClosureOperation<DepositOperationData> {
            guard
                let selected = try fetchDeposit
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw CancellingError.noDeposits
            }

            return selected
        }

        selectDeposit.addDependency(fetchDeposit)

        let saveStatusClosure: () throws -> [DepositOperationData] = {
            let changed = try selectDeposit
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .changingStatus(.depositReceived)
            return [changed]
        }

        let saveOperation = depositRepository.saveOperation(saveStatusClosure, { [] })
        saveOperation.addDependency(selectDeposit)

        let dependencies = [fetchDeposit, selectDeposit]

        return CompoundOperationWrapper(targetOperation: saveOperation,
                                        dependencies: dependencies)
    }
}

extension DepositDataStreamProcessor: DataStreamProcessing {
    func process(event: DataStreamOneOfEvent) {
        switch event {
        case .depositCompleted(let event):
            handleDepositedEvent(event)
        default:
            break
        }
    }

    func processOutOfSync() {}
}
