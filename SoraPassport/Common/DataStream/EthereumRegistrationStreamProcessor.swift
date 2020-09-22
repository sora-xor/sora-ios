/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class EthereumRegistrationStreamProcessor {
    let repository: AnyDataProviderRepository<EthereumInit>
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(repository: AnyDataProviderRepository<EthereumInit>,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.repository = repository
        self.operationManager = operationManager
        self.logger = logger
    }

    // MARK: Private

    private func handleOperationStarted(_ event: EthRegistrationStartedStreamEvent) {
        let saveClosure: () throws -> [EthereumInit] = {
            let userInfo = EthereumInitUserInfo(address: event.address, failureReason: nil)
            let item = EthereumInit(sidechainId: SidechainId.eth,
                                    state: .inProgress,
                                    userInfo: userInfo)
            return [item]
        }

        let saveOperation = repository.saveOperation(saveClosure, { [] })

        saveOperation.completionBlock = {
            do {
                try saveOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                self.logger
                    .debug("Eth registration started: \(event.operationId) \(event.address)")
            } catch {
                self.logger.debug("Did fail to handle eth registration started: \(error)")
            }
        }

        operationManager.enqueue(operations: [saveOperation], in: .sync)
    }

    private func handleOperationCompleted(_ event: EthRegistrationCompletedStreamEvent) {
        let fetchOperation = repository.fetchOperation(by: SidechainId.eth.rawValue,
                                                   options: RepositoryFetchOptions())

        let saveClosure: () throws -> [EthereumInit] = {
            if let item = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) {
                let changed = EthereumInit(sidechainId: item.sidechainId,
                                           state: .completed,
                                           userInfo: item.userInfo)
                return [changed]
            } else {
                let item = EthereumInit(sidechainId: SidechainId.eth,
                                        state: .completed,
                                        userInfo: nil)
                return [item]
            }
        }

        let saveOperation = repository.saveOperation(saveClosure, { [] })
        saveOperation.addDependency(fetchOperation)

        saveOperation.completionBlock = {
            do {
                try saveOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                self.logger.debug("Eth registration completed: \(event.operationId)")
            } catch {
                self.logger.debug("Eth registration completed: \(error)")
            }
        }

        operationManager.enqueue(operations: [fetchOperation, saveOperation], in: .sync)
    }

    private func handleOperationFailed(_ event: EthRegistrationFailedStreamEvent) {
        let fetchOperation = repository.fetchOperation(by: SidechainId.eth.rawValue,
                                                   options: RepositoryFetchOptions())

        let saveClosure: () throws -> [EthereumInit] = {
            if let item = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) {

                let userInfo: EthereumInitUserInfo?

                if let currentInfo = item.userInfo {
                    userInfo = EthereumInitUserInfo(address: currentInfo.address,
                                                    failureReason: currentInfo.failureReason)
                } else {
                    userInfo = nil
                }

                let changed = EthereumInit(sidechainId: item.sidechainId,
                                           state: .failed,
                                           userInfo: userInfo)
                return [changed]
            } else {
                let item = EthereumInit(sidechainId: SidechainId.eth,
                                        state: .failed,
                                        userInfo: nil)
                return [item]
            }
        }

        let saveOperation = repository.saveOperation(saveClosure, { [] })
        saveOperation.addDependency(fetchOperation)

        saveOperation.completionBlock = {
            do {
                try saveOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                self.logger
                    .debug("Eth registration failed: \(event.operationId) \(String(describing: event.reason))")
            } catch {
                self.logger.debug("Eth registration failed: \(error)")
            }
        }

        operationManager.enqueue(operations: [fetchOperation, saveOperation], in: .sync)
    }
}

extension EthereumRegistrationStreamProcessor: DataStreamProcessing {
    func process(event: DataStreamOneOfEvent) {
        switch event {
        case .ethRegistrationStarted(let event):
            handleOperationStarted(event)
        case .ethRegistrationCompleted(let event):
            handleOperationCompleted(event)
        case .ethRegistrationFailed(let event):
            handleOperationFailed(event)
        default:
            break
        }
    }

    func processOutOfSync() {}
}
