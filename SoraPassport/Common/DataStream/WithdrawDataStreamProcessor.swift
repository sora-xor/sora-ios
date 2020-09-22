/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import CommonWallet
import BigInt

enum WithdrawDataStreamProcessorError: Error {
    case missingLocalWithdraw
}

final class WithdrawDataStreamProcessor {
    let repository: AnyDataProviderRepository<WithdrawOperationData>
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(repository: AnyDataProviderRepository<WithdrawOperationData>,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.repository = repository
        self.operationManager = operationManager
        self.logger = logger
    }

    func handleFailed(transactionId: String) {
        let fetchOperation = repository.fetchOperation(by: transactionId,
                                                       options: RepositoryFetchOptions())

        let saveClosure: () throws -> [WithdrawOperationData] = {
            guard
                let fetched = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                return []
            }

            switch fetched.status {
            case .intentSent, .intentPending:
                let changed = fetched.changingStatus(.intentFailed)
                return [changed]
            default:
                return []
            }
        }

        let saveOperation = repository.saveOperation(saveClosure, { [] })
        saveOperation.addDependency(fetchOperation)

        operationManager.enqueue(operations: [fetchOperation, saveOperation], in: .sync)
    }

    func handleCompleted(transactionId: String) {
        let wrapper = createStatusChangeForIntent(transactionId)

        wrapper.targetOperation.completionBlock = {
            do {
                _ = try wrapper.targetOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                self.logger.debug("Withdraw proofs receive receive successfully handled")
            } catch {
                self.logger.debug("No withdraw proofs receive handling failed: \(error)")
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .sync)
    }

    // MARK: Private

    private func createStatusChangeForIntent(_ transactionId: String) -> CompoundOperationWrapper<Void> {
        let fetchOperation = repository.fetchOperation(by: transactionId,
                                                       options: RepositoryFetchOptions())

        let completionSaveClosure: () throws -> [WithdrawOperationData] = {
            guard
                let fetched = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw WithdrawDataStreamProcessorError.missingLocalWithdraw
            }

            switch fetched.status {
            case .intentSent:
                let changed = fetched.changingStatus(.intentCompleted)
                return [changed]
            case .intentPending:
                let changed = fetched.changingStatus(.intentFinalized)
                return [changed]
            default:
                return []
            }
        }

        let completionSaveOperation = repository.saveOperation(completionSaveClosure, { [] })
        completionSaveOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: completionSaveOperation,
                                        dependencies: [fetchOperation])
    }
}

extension WithdrawDataStreamProcessor: DataStreamProcessing {
    func process(event: DataStreamOneOfEvent) {
        switch event {
        case .operationFailed(let event):
            handleFailed(transactionId: event.operationId)
        case .operationCompleted(let event):
            handleCompleted(transactionId: event.operationId)
        default:
            break
        }
    }

    func processOutOfSync() {}
}
