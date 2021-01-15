/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import BigInt

final class WithdrawTransferFinalizationService {
    enum OperationError: Error {
        case missingLocalWithdraw
        case invalidAmount
        case invalidFeeDescription
        case invalidGasPrice
        case invalidGasLimit
        case handlingTimeout
    }

    private enum CancellingError: Error {
        case noCompletedWithdraw
        case noTransfer
    }

    let ethereumOperationFactory: EthereumOperationFactoryProtocol
    let repository: AnyDataProviderRepository<WithdrawOperationData>
    let repositoryObserver: CoreDataContextObservable<WithdrawOperationData, CDWithdraw>
    let operationManager: OperationManagerProtocol
    let masterContract: Data
    let automaticHandlingDelay: TimeInterval
    let logger: LoggerProtocol

    init(ethereumOperationFactory: EthereumOperationFactoryProtocol,
         repository: AnyDataProviderRepository<WithdrawOperationData>,
         repositoryObserver: CoreDataContextObservable<WithdrawOperationData, CDWithdraw>,
         operationManager: OperationManagerProtocol,
         masterContract: Data,
         automaticHandlingDelay: TimeInterval,
         logger: LoggerProtocol) {
        self.ethereumOperationFactory = ethereumOperationFactory
        self.repository = repository
        self.repositoryObserver = repositoryObserver
        self.operationManager = operationManager
        self.masterContract = masterContract
        self.automaticHandlingDelay = automaticHandlingDelay
        self.logger = logger
    }

    // MARK: Private

    private func handleWithdrawWithIdentifier(_ identifier: String) {
        let statusChange = createStatusChangeForWithdrawIdentifier(identifier)

        let finalization = createFinalizationDependingOn(fetchOperation: statusChange.targetOperation)

        finalization.allOperations.forEach { finalizationOperation in
            statusChange.allOperations.forEach { finalizationOperation.addDependency($0) }
        }

        let completionSaving =
            createCompletionSavingDependingOn(transactionOperation: finalization.targetOperation,
                                              localFetchOperation: statusChange.targetOperation)

        completionSaving.allOperations.forEach { completionSavingOperation in
            finalization.allOperations.forEach { completionSavingOperation.addDependency($0) }
        }

        let operations = statusChange.allOperations + finalization.allOperations +
            completionSaving.allOperations

        completionSaving.targetOperation.completionBlock = {
            do {
                try completionSaving.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                let transferHash = try finalization.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    .soraHexWithPrefix

                self.logger.debug("Withdraw transfer automatically completed: \(transferHash)")
            } catch {
                if error is CancellingError {
                    self.logger.warning("Withdraw transfer cancelled: \(error)")
                } else {
                    self.logger.warning("Can't automatically complete withdraw: \(error)")
                }
            }
        }

        operationManager.enqueue(operations: operations, in: .sync)
    }

    private func createStatusChangeForWithdrawIdentifier(_ identifier: String)
        -> CompoundOperationWrapper<WithdrawOperationData> {
        let fetchOperation = repository.fetchOperation(by: identifier,
                                                       options: RepositoryFetchOptions())

        let completionSaveClosure: () throws -> [WithdrawOperationData] = {
            guard
                let fetched = try fetchOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw WithdrawDataStreamProcessorError.missingLocalWithdraw
            }

            if fetched.status == .confirmationCompleted {
                let changed = fetched.changingStatus(.confirmationFinalized)
                return [changed]
            } else {
                return []
            }
        }

        let completionSaveOperation = repository.saveOperation(completionSaveClosure, { [] })
        completionSaveOperation.addDependency(fetchOperation)

        let combiningOperation = ClosureOperation<WithdrawOperationData> {
            guard
                let fetched = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw OperationError.missingLocalWithdraw
            }

            try completionSaveOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return fetched
        }

        combiningOperation.addDependency(completionSaveOperation)

        return CompoundOperationWrapper(targetOperation: combiningOperation,
                                        dependencies: [fetchOperation, completionSaveOperation])
    }

    private func createFinalizationDependingOn(fetchOperation: BaseOperation<WithdrawOperationData>)
        -> CompoundOperationWrapper<Data> {

        let delay = automaticHandlingDelay

        let validationOperation = ClosureOperation<WithdrawOperationData> {
            let withdrawData = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard withdrawData.status == .confirmationCompleted else {
                throw CancellingError.noCompletedWithdraw
            }

            guard Date().timeIntervalSince1970 - TimeInterval(withdrawData.timestamp) <= delay  else {
                throw OperationError.handlingTimeout
            }

            guard withdrawData.transferAmount != nil else {
                throw CancellingError.noTransfer
            }

            return withdrawData
        }

        let tokenAddressOperation = ethereumOperationFactory
            .createXORAddressFetchOperation(from: masterContract)

        tokenAddressOperation.configurationBlock = {
            do {
                _ = try validationOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            } catch {
                tokenAddressOperation.result = .failure(error)
            }
        }

        tokenAddressOperation.addDependency(validationOperation)

        let ethERC20Config: EthERC20TransferConfig = {
            let data = try validationOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard
                let decimalAmount = data.transferAmount,
                let amount = decimalAmount.decimalValue.toEthereumAmount() else {
                throw OperationError.invalidAmount
            }

            let tokenAddress = try tokenAddressOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return ERC20TransferInfo(tokenAddress: tokenAddress,
                                     destinationAddress: Data(hex: data.receiver),
                                     amount: amount)
        }

        let transferTransactionOperation = ethereumOperationFactory
            .createERC20TransferTransactionOperation(for: ethERC20Config)

        transferTransactionOperation.addDependency(tokenAddressOperation)

        let nonceOperation = ethereumOperationFactory.createTransactionsCountOperation(with: .pending)

        nonceOperation.configurationBlock = {
            do {
                _ = try transferTransactionOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            } catch {
                nonceOperation.result = .failure(error)
            }
        }

        nonceOperation.addDependency(transferTransactionOperation)

        let transactionConfig: EthReadyTransactionConfig = {
            let ethFeeId = WalletNetworkConstants.ethFeeIdentifier
            guard
                let fee: EthFeeParameters = try fetchOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    .fees.first(where: { $0.feeDescription.identifier == ethFeeId })?
                    .feeDescription.parameters else {
                throw OperationError.invalidFeeDescription
            }

            guard let gasPrice = fee.gasPrice.decimalValue.toEthereumAmount() else {
                throw OperationError.invalidGasPrice
            }

            guard let gasLimit = BigUInt(fee.transferGas.stringValue) else {
                throw OperationError.invalidGasLimit
            }

            let txData = try transferTransactionOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let nonce = try nonceOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return EthereumTransactionInfo(txData: txData,
                                           gasPrice: gasPrice,
                                           gasLimit: gasLimit,
                                           nonce: nonce)
        }

        let sendTransactionOperation = ethereumOperationFactory
            .createSendTransactionOperation(for: transactionConfig)

        sendTransactionOperation.addDependency(nonceOperation)
        sendTransactionOperation.addDependency(transferTransactionOperation)

        let dependencies = [validationOperation, tokenAddressOperation, nonceOperation, transferTransactionOperation]

        return CompoundOperationWrapper(targetOperation: sendTransactionOperation,
                                        dependencies: dependencies)
    }

    private func createCompletionSavingDependingOn(transactionOperation: BaseOperation<Data>,
                                                   localFetchOperation: BaseOperation<WithdrawOperationData>)
        -> CompoundOperationWrapper<Void> {

        let updateClosure: () throws -> [WithdrawOperationData] = {
            let fetched = try localFetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            do {
                let transferHashData = try transactionOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                let changed = fetched
                    .changing(transferId: transferHashData.soraHex)
                    .changingStatus(.transferPending)
                return [changed]
            } catch {
                if error is CancellingError {
                    return []
                } else {
                    let changed = fetched.changingStatus(.transferFailed)
                    self.logger.debug("transferFailed, \(error) in completionSaving, transferFinalization")
                    return [changed]
                }
            }
        }

        let updateOperation = repository.saveOperation(updateClosure, { [] })

        return CompoundOperationWrapper(targetOperation: updateOperation)
    }

}

extension WithdrawTransferFinalizationService: UserApplicationServiceProtocol {
    func setup() {
        repositoryObserver.addObserver(self, deliverOn: .main) { [weak self] changes in
            for change in changes {
                switch change {
                case .insert(let newItem), .update(let newItem):
                    if newItem.status == .confirmationCompleted {
                        self?.handleWithdrawWithIdentifier(newItem.identifier)
                    }
                default:
                    break
                }
            }
        }
    }

    func throttle() {
        repositoryObserver.removeObserver(self)
    }
}
