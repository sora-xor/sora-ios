/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import CommonWallet

final class DepositFinalizationService {
    enum OperationError: Error {
        case noDeposit
        case handlingTimeout
    }

    enum CancellingError: Error {
        case wrongStatus
        case noTransfer
    }

    let walletOperationFactory: WalletAsyncOperationFactoryProtocol
    let repository: AnyDataProviderRepository<DepositOperationData>
    let observer: CoreDataContextObservable<DepositOperationData, CDDeposit>
    let operationManager: OperationManagerProtocol
    let automaticHandlingDelay: TimeInterval
    let logger: LoggerProtocol

    init(walletOperationFactory: WalletAsyncOperationFactoryProtocol,
         repository: AnyDataProviderRepository<DepositOperationData>,
         observer: CoreDataContextObservable<DepositOperationData, CDDeposit>,
         operationManager: OperationManagerProtocol,
         automaticHandlingDelay: TimeInterval,
         logger: LoggerProtocol) {
        self.walletOperationFactory = walletOperationFactory
        self.repository = repository
        self.observer = observer
        self.operationManager = operationManager
        self.automaticHandlingDelay = automaticHandlingDelay
        self.logger = logger
    }

    // MARK: Private

    private func handle(depositIdentifier: String) {
        let completionSaving = createDepositStatusSavingForId(depositIdentifier)

        let transfer = createTransferCompletion(dependingOn: completionSaving.targetOperation)

        completionSaving.allOperations.forEach { completionSavingOperation in
            transfer.allOperations.forEach { $0.addDependency(completionSavingOperation) }
        }

        let finalization = createTransferFinalization(dependingOn: transfer.targetOperation,
                                                      localFetchOperation: completionSaving.targetOperation)

        transfer.allOperations.forEach { transferOperation in
            finalization.allOperations.forEach { $0.addDependency(transferOperation) }
        }

        finalization.targetOperation.completionBlock = {
            do {
                try finalization.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                let transactionId = try transfer.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                self.logger.debug("Did complete start subsequent transfer: \(transactionId.soraHex)")
            } catch {
                if let cancellingError = error as? CancellingError {
                    self.logger.debug("Did cancel subsequent transfer: \(cancellingError)")
                } else {
                    self.logger.error("Can't complete deposit transfer: \(error)")
                }
            }
        }

        let operations = completionSaving.allOperations + transfer.allOperations + finalization.allOperations

        operationManager.enqueue(operations: operations, in: .sync)
    }

    private func createTransferFinalization(dependingOn transferOperation: BaseOperation<Data>,
                                            localFetchOperation: BaseOperation<DepositOperationData>)
        -> CompoundOperationWrapper<Void> {
        let saveClosure: () throws -> [DepositOperationData]  = {
            let fetched = try localFetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            do {
                let trasferId = try transferOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    .soraHex

                let changed = fetched
                    .changing(newTransferId: trasferId)
                    .changingStatus(.transferPending)

                return [changed]
            } catch {
                if error is CancellingError {
                    return []
                }

                let changed = fetched.changingStatus(.transferFailed)
                return [changed]
            }
        }

        let saveOperation = repository.saveOperation(saveClosure, { [] })

        return CompoundOperationWrapper(targetOperation: saveOperation)
    }

    private func createTransferCompletion(dependingOn localFetch: BaseOperation<DepositOperationData>)
        -> CompoundOperationWrapper<Data> {

        let delay = automaticHandlingDelay

        let transferInfoClosure: () throws -> TransferInfo = {
            let selected = try localFetch
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard selected.status == .depositReceived else {
                throw CancellingError.wrongStatus
            }

            guard Date().timeIntervalSince1970 - TimeInterval(selected.timestamp) <= delay  else {
                throw OperationError.handlingTimeout
            }

            guard let amount = selected.transferAmount else {
                throw CancellingError.noTransfer
            }

            let fees = selected.fees.filter { $0.feeDescription.assetId == selected.assetId }

            return TransferInfo(source: selected.sender,
                                destination: selected.receiver,
                                amount: amount,
                                asset: selected.assetId,
                                details: selected.note ?? "",
                                fees: fees)
        }

        let transfer = walletOperationFactory.transferOperation(transferInfoClosure)

        return transfer
    }

    private func createDepositStatusSavingForId(_ identifier: String)
        -> CompoundOperationWrapper<DepositOperationData> {
        let depositOperation = repository.fetchOperation(by: identifier, options: RepositoryFetchOptions())

        let saveStatusClosure: () throws -> [DepositOperationData] = {
            guard
                let selectedDeposit = try depositOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled),
                selectedDeposit.status == .depositReceived else {
                return []
            }

            let changed = selectedDeposit.changingStatus(.depositFinalized)
            return [changed]
        }

        let saveOperation = repository.saveOperation(saveStatusClosure, { [] })
        saveOperation.addDependency(depositOperation)

        let combiningOperation = ClosureOperation<DepositOperationData> {
            guard
                let selectedDeposit = try depositOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw OperationError.noDeposit
            }

            try saveOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return selectedDeposit
        }

        combiningOperation.addDependency(saveOperation)

        let dependencies = [depositOperation, saveOperation]

        return CompoundOperationWrapper(targetOperation: combiningOperation,
                                        dependencies: dependencies)
    }
}

extension DepositFinalizationService: UserApplicationServiceProtocol {
    func setup() {
        observer.addObserver(self, deliverOn: .main) { [weak self] changes in
            for change in changes {
                switch change {
                case .insert(let newItem), .update(let newItem):
                    if newItem.status == .depositReceived {
                        self?.handle(depositIdentifier: newItem.identifier)
                    }
                default:
                    break
                }
            }
        }
    }

    func throttle() {
        observer.removeObserver(self)
    }
}
