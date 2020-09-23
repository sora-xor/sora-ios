/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class SoranetTransferProcessor {
    let repository: AnyDataProviderRepository<DepositOperationData>
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(repository: AnyDataProviderRepository<DepositOperationData>,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.repository = repository
        self.operationManager = operationManager
        self.logger = logger
    }

    func handleTransactionId(_ transactionId: String, isCompleted: Bool) {
        logger.debug("Did start handling soranet outgoing transfer: \(transactionId)")

        let deposits = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let saveClosure: () -> [DepositOperationData] = {
            do {
                if let selected = try deposits
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    .first(where: { $0.transferTransactionId == transactionId }) {
                    let status: DepositOperationData.Status = isCompleted ? .transferCompleted
                        : .transferFailed
                    let changed = selected.changingStatus(status)
                    return [changed]
                } else {
                    return []
                }
            } catch {
                return []
            }
        }

        let save = repository.saveOperation(saveClosure, { [] })
        save.addDependency(deposits)

        save.completionBlock = {
            self.logger.debug("Did complete handling soranet outgoing transfer: \(transactionId)")
        }

        operationManager.enqueue(operations: [deposits, save], in: .sync)
    }
}

extension SoranetTransferProcessor: DataStreamProcessing {
    func process(event: DataStreamOneOfEvent) {
        switch event {
        case .operationCompleted(let event):
            if event.type == WalletTransactionTypeValue.outgoing.rawValue {
                handleTransactionId(event.operationId, isCompleted: true)
            }
        case .operationFailed(let event):
            if event.type == WalletTransactionTypeValue.outgoing.rawValue {
                handleTransactionId(event.operationId, isCompleted: false)
            }
        default:
            break
        }
    }

    func processOutOfSync() {}
}
