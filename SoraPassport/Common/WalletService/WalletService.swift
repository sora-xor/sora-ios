// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import RobinHood

enum WalletServiceError: Error {
    case invalidPageHash
}

final class WalletService {
    let operationQueue: OperationQueue
    let operationFactory: WalletNetworkOperationFactoryProtocol

    init(operationFactory: WalletNetworkOperationFactoryProtocol,
         operationQueue: OperationQueue = OperationQueue()) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }
}

extension WalletService: WalletServiceProtocol {

    @discardableResult
    func fetchBalance(for assets: [String],
                      runCompletionIn queue: DispatchQueue,
                      completionBlock: @escaping BalanceCompletionBlock) -> CancellableCall {
        let operationsWrapper = operationFactory.fetchBalanceOperation(assets)

        operationsWrapper.targetOperation.completionBlock = {
            queue.async {
                completionBlock(operationsWrapper.targetOperation.result)
            }
        }

        operationQueue.addOperations(operationsWrapper.allOperations,
                                     waitUntilFinished: false)

        return operationsWrapper
    }

    @discardableResult
    func fetchTransactionHistory(for filter: WalletHistoryRequest,
                                 pagination: Pagination,
                                 runCompletionIn queue: DispatchQueue,
                                 completionBlock: @escaping TransactionHistoryBlock)
        -> CancellableCall {

        let operationWrapper = operationFactory.fetchTransactionHistoryOperation(filter,
                                                                                 pagination: pagination)

        operationWrapper.targetOperation.completionBlock = {
            queue.async {
                completionBlock(operationWrapper.targetOperation.result)
            }
        }

        operationQueue.addOperations(operationWrapper.allOperations,
                                     waitUntilFinished: false)

        return operationWrapper
    }

    @discardableResult
    func fetchTransferMetadata(for info: TransferMetadataInfo,
                               runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping TransferMetadataCompletionBlock)
        -> CancellableCall {

        let operationWrapper = operationFactory.transferMetadataOperation(info)

        operationWrapper.targetOperation.completionBlock = {
            queue.async {
                completionBlock(operationWrapper.targetOperation.result)
            }
        }

        operationQueue.addOperations(operationWrapper.allOperations,
                                     waitUntilFinished: false)

        return operationWrapper
    }

    @discardableResult
    func transfer(info: TransferInfo,
                  runCompletionIn queue: DispatchQueue,
                  completionBlock: @escaping DataResultCompletionBlock)
        -> CancellableCall {

        let operationWrapper = operationFactory.transferOperation(info)

        operationWrapper.targetOperation.completionBlock = {
            queue.async {
                completionBlock(operationWrapper.targetOperation.result)
            }
        }

        operationQueue.addOperations(operationWrapper.allOperations,
                                     waitUntilFinished: false)

        return operationWrapper
    }

    func prepareTransferSubmission(
        for info: TransferInfo,
        preSigningValidation: @escaping () throws -> Void
    ) async throws -> PreparedSora2TransferSubmission {
        try await operationFactory.prepareTransferSubmission(
            for: info,
            preSigningValidation: preSigningValidation
        )
    }

    func submitPreparedTransfer(
        _ submission: PreparedSora2TransferSubmission,
        info: TransferInfo,
        preTransportValidation: @escaping () throws -> Void
    ) async throws -> Data {
        try await operationFactory.submitPreparedTransfer(
            submission,
            info: info,
            preTransportValidation: preTransportValidation
        )
    }

    @discardableResult
    func search(for searchString: String,
                runCompletionIn queue: DispatchQueue,
                completionBlock: @escaping SearchCompletionBlock)
        -> CancellableCall {

        let operationWrapper = operationFactory.searchOperation(searchString)

        operationWrapper.targetOperation.completionBlock = {
            queue.async {
                completionBlock(operationWrapper.targetOperation.result)
            }
        }

        operationQueue.addOperations(operationWrapper.allOperations, waitUntilFinished: false)

        return operationWrapper
    }

    @discardableResult
    func fetchContacts(runCompletionIn queue: DispatchQueue,
                       completionBlock: @escaping SearchCompletionBlock)
        -> CancellableCall {
        let operationWrapper = operationFactory.contactsOperation()
        
        operationWrapper.targetOperation.completionBlock = {
            queue.async {
                completionBlock(operationWrapper.targetOperation.result)
            }
        }
        
        operationQueue.addOperations(operationWrapper.allOperations, waitUntilFinished: false)
        
        return operationWrapper
    }

    @discardableResult
    func fetchWithdrawalMetadata(for info: WithdrawMetadataInfo,
                                 runCompletionIn queue: DispatchQueue,
                                 completionBlock: @escaping WithdrawalMetadataCompletionBlock)
        -> CancellableCall {
        let operationWrapper = operationFactory.withdrawalMetadataOperation(info)

        operationWrapper.targetOperation.completionBlock = {
            queue.async {
                completionBlock(operationWrapper.targetOperation.result)
            }
        }

        operationQueue.addOperations(operationWrapper.allOperations, waitUntilFinished: false)

        return operationWrapper
    }

    @discardableResult
    func withdraw(info: WithdrawInfo,
                  runCompletionIn queue: DispatchQueue,
                  completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall {
        let operationWrapper = operationFactory.withdrawOperation(info)

        operationWrapper.targetOperation.completionBlock = {
            queue.async {
                completionBlock(operationWrapper.targetOperation.result)
            }
        }

        operationQueue.addOperations(operationWrapper.allOperations, waitUntilFinished: false)

        return operationWrapper
    }
}
