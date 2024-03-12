// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
