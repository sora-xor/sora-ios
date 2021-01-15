/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import BigInt

final class WithdrawProofsFinalizationService {
    enum OperationError: Error {
        case missingLocalWithdraw
        case proofDataMissing
        case invalidAmount
        case invalidFeeDescription
        case invalidGasPrice
        case invalidGasLimit
        case handlingTimeout
    }

    private enum CancellingError: Error {
        case intentAlreadyUsed
        case noCompletedIntent
    }

    let accountId: String
    let ethereumOperationFactory: EthereumOperationFactoryProtocol
    let soranetOperationFactory: SoranetUnitOperationFactoryProtocol
    let soranetUnit: ServiceUnit
    let repository: AnyDataProviderRepository<WithdrawOperationData>
    let repositoryObserver: CoreDataContextObservable<WithdrawOperationData, CDWithdraw>
    let operationManager: OperationManagerProtocol
    let masterContract: Data
    let automaticHandlingDelay: TimeInterval
    let logger: LoggerProtocol

    init(accountId: String,
         ethereumOperationFactory: EthereumOperationFactoryProtocol,
         soranetOperationFactory: SoranetUnitOperationFactoryProtocol,
         soranetUnit: ServiceUnit,
         repository: AnyDataProviderRepository<WithdrawOperationData>,
         repositoryObserver: CoreDataContextObservable<WithdrawOperationData, CDWithdraw>,
         operationManager: OperationManagerProtocol,
         masterContract: Data,
         automaticHandlingDelay: TimeInterval,
         logger: LoggerProtocol) {
        self.accountId = accountId
        self.ethereumOperationFactory = ethereumOperationFactory
        self.soranetOperationFactory = soranetOperationFactory
        self.soranetUnit = soranetUnit
        self.repository = repository
        self.repositoryObserver = repositoryObserver
        self.operationManager = operationManager
        self.masterContract = masterContract
        self.automaticHandlingDelay = automaticHandlingDelay
        self.logger = logger
    }

    // MARK: Private

    private func handleWithdrawWithIdentifier(_ identifier: String) {
        let statusChange = createStatusChangeForIntentIdentifier(identifier)

        if
            let proofUrlTemplate = soranetUnit
                .service(for: SoranetServiceType.withdrawProof.rawValue)?
                .serviceEndpoint,
            let intentHash = Data(hexString: identifier) {

            let finalization = createFinalizationDependingOn(fetchOperation: statusChange.targetOperation,
                                                             intentHash: intentHash,
                                                             proofUrlTemplate: proofUrlTemplate)

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

                    self.logger.debug("Withdraw automatically completed for intent: \(identifier)")
                } catch {
                    self.logger.warning("Can't automatically complete withdraw: \(error)")
                }
            }

            operationManager.enqueue(operations: operations, in: .sync)
        } else {
            operationManager.enqueue(operations: statusChange.allOperations, in: .sync)
        }
    }

    private func createStatusChangeForIntentIdentifier(_ identifier: String)
        -> CompoundOperationWrapper<WithdrawOperationData> {
        let fetchOperation = repository.fetchOperation(by: identifier,
                                                       options: RepositoryFetchOptions())

        let completionSaveClosure: () throws -> [WithdrawOperationData] = {
            guard
                let fetched = try fetchOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw OperationError.missingLocalWithdraw
            }

            if fetched.status == .intentCompleted {
                let changed = fetched.changingStatus(.intentFinalized)
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
                throw WithdrawDataStreamProcessorError.missingLocalWithdraw
            }

            try completionSaveOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return fetched
        }

        combiningOperation.addDependency(completionSaveOperation)

        return CompoundOperationWrapper(targetOperation: combiningOperation,
                                        dependencies: [fetchOperation, completionSaveOperation])
    }

    private func createFinalizationDependingOn(fetchOperation: BaseOperation<WithdrawOperationData>,
                                               intentHash: Data,
                                               proofUrlTemplate: String)
        -> CompoundOperationWrapper<Data> {

        let intentStatusOperation = ethereumOperationFactory
            .createWithdrawalCheckOperation(for: { intentHash },
                                            masterContractAddress: masterContract)

        let delay = automaticHandlingDelay

        intentStatusOperation.configurationBlock = {
            do {
                let withdrawData = try fetchOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                guard withdrawData.status == .intentCompleted else {
                    throw CancellingError.noCompletedIntent
                }

                guard Date().timeIntervalSince1970 - TimeInterval(withdrawData.timestamp) <= delay  else {
                    throw OperationError.handlingTimeout
                }

            } catch {
                intentStatusOperation.result = .failure(error)
            }
        }

        let withdrawInfo = WithdrawProofInfo(accountId: accountId, intentionHash: intentHash)
        let proofsOperation = soranetOperationFactory.withdrawProofOperation(proofUrlTemplate,
                                                                             info: withdrawInfo)

        proofsOperation.configurationBlock = {
            do {
                let isUsed = try intentStatusOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                if isUsed {
                    throw CancellingError.intentAlreadyUsed
                }
            } catch {
                proofsOperation.result = .failure(error)
            }
        }

        proofsOperation.addDependency(intentStatusOperation)

        let ethWithdrawInfoConfig: EthWithdrawInfoConfig = {
            guard let proofData = try proofsOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw OperationError.proofDataMissing
            }

            guard let amount = BigUInt(proofData.amount) else {
                throw OperationError.invalidAmount
            }

            return EthereumWithdrawInfo(txHash: intentHash,
                                        amount: amount,
                                        proof: proofData.proofs,
                                        destination: proofData.destination)
        }

        let tokenAddressOperation = ethereumOperationFactory
            .createXORAddressFetchOperation(from: masterContract)

        tokenAddressOperation.configurationBlock = {
            do {
                _ = try proofsOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            } catch {
                tokenAddressOperation.result = .failure(error)
            }
        }

        let tokenAddressConfig: EthAddressConfig = {
            try tokenAddressOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }

        let withdrawTransactionOperation = ethereumOperationFactory
            .createWithdrawTransactionOperation(for: ethWithdrawInfoConfig,
                                                tokenAddressConfig: tokenAddressConfig,
                                                masterContractAddress: masterContract)

        withdrawTransactionOperation.addDependency(tokenAddressOperation)

        let nonceOperation = ethereumOperationFactory.createTransactionsCountOperation(with: .pending)

         nonceOperation.configurationBlock = {
            do {
                _ = try proofsOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            } catch {
                nonceOperation.result = .failure(error)
            }
        }

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

            guard let gasLimit = BigUInt(fee.mintGas.stringValue) else {
                throw OperationError.invalidGasLimit
            }

            let txData = try withdrawTransactionOperation
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

        let ethDependencies = [tokenAddressOperation, nonceOperation, withdrawTransactionOperation]

        ethDependencies.forEach {
            $0.addDependency(proofsOperation)
            sendTransactionOperation.addDependency($0)
        }

        let intentDependencies = [intentStatusOperation, proofsOperation]

        return CompoundOperationWrapper(targetOperation: sendTransactionOperation,
                                        dependencies: intentDependencies + ethDependencies)
    }

    private func createCompletionSavingDependingOn(transactionOperation: BaseOperation<Data>,
                                                   localFetchOperation: BaseOperation<WithdrawOperationData>)
        -> CompoundOperationWrapper<Void> {

        let updateClosure: () throws -> [WithdrawOperationData] = {
            let fetched = try localFetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            do {
                let confirmationHashData = try transactionOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                let changed = fetched
                    .changing(newConfirmationId: confirmationHashData.soraHex)
                    .changingStatus(.confirmationPending)
                return [changed]
            } catch {
                if let cancellingError = error as? CancellingError, cancellingError == .intentAlreadyUsed {
                    let changed = fetched.changingStatus(.confirmationCompleted)
                    return [changed]
                } else if let ethError = error as? NSError, ethError.domain == EthereumServiceConstants.errorDomain {
                    let changed = fetched.changingStatus(.confirmationFailed)
                    self.logger.debug("confirmationFailed, eth error in proof finalization")
                    return [changed]
                } else {
                    throw error
                }
            }
        }

        let updateOperation = repository.saveOperation(updateClosure, { [] })

        return CompoundOperationWrapper(targetOperation: updateOperation)
    }
}

extension WithdrawProofsFinalizationService: UserApplicationServiceProtocol {
    func setup() {
        repositoryObserver.addObserver(self, deliverOn: .main) { [weak self] changes in
            for change in changes {
                switch change {
                case .insert(let newItem), .update(let newItem):
                    if newItem.status == .intentCompleted {
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
