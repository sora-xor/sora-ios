import Foundation
import RobinHood
import CommonWallet

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
