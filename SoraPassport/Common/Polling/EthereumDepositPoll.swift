/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class EthereumDepositPoll: EthereumBasePoll<DepositOperationData, CDDeposit> {
    override func updateTransactionIdsWithChanges(_ changes: [DataProviderChange<DepositOperationData>]) {
        for change in changes {
            switch change {
            case .insert(let newItem), .update(let newItem):
                if
                    newItem.status == .depositPending {
                    transactionIds[newItem.identifier] = newItem.depositTransactionId
                } else {
                    transactionIds.removeValue(forKey: newItem.identifier)
                }
            default:
                break
            }
        }
    }

    override func createPollForIdentifier(_ identifier: String) -> CompoundOperationWrapper<Void> {
        guard
            let transactionId = transactionIds[identifier],
            let transactionHash = Data(hexString: transactionId) else {

            let operation = BaseOperation<Void>()
            operation.result = .failure(BaseOperationError.unexpectedDependentResult)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let remoteTransactionOperation = operationFactory
            .createTransactionByHashFetchOperation(transactionHash)
        let localTransactionOperation = repository.fetchOperation(by: identifier,
                                                                  options: RepositoryFetchOptions())
        localTransactionOperation.addDependency(remoteTransactionOperation)

        let saveClosure: () throws -> [DepositOperationData] = {
            guard
                let localTransaction = try localTransactionOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled),
                localTransaction.status == .depositPending else {
                return []
            }

            let optionalRemoteTransaction = try remoteTransactionOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            if let remoteTransaction = optionalRemoteTransaction {
                if remoteTransaction.blockHash != nil {
                    let changed = localTransaction.changingStatus(.depositCommited)
                    return [changed]
                } else {
                    return []
                }
            } else {
                let changed = localTransaction.changingStatus(.depositFailed)
                return [changed]
            }
        }

        let saveOperation = repository.saveOperation(saveClosure, { [] })
        saveOperation.addDependency(localTransactionOperation)

        return CompoundOperationWrapper(targetOperation: saveOperation,
                                        dependencies: [remoteTransactionOperation, localTransactionOperation])
    }
}
