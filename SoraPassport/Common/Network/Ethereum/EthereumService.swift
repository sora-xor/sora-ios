import Foundation
import SoraKeystore
import RobinHood
import BigInt

final class EthereumService: BaseService, EthereumServiceProtocol {

    private let operationFactory: EthereumOperationFactoryProtocol

    private let masterContractAddress: Data

    init(node: URL, masterContractAddress: Data,
         keystore: EthereumKeystoreProtocol,
         chain: EthereumChain = .mainnet) throws {
        operationFactory = try EthereumOperationFactory(node: node, keystore: keystore, chain: chain)
        self.masterContractAddress = masterContractAddress
    }

    private func createNonceCombinigOperation(for operations: [BaseOperation<BigUInt>]) -> BaseOperation<BigUInt> {
        let combiningOperation: BaseOperation<BigUInt> = ClosureOperation {
            var result = BigUInt(0)

            for operation in operations {
                let operationResult = try operation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                result += operationResult
            }

            return result
        }

        operations.forEach { combiningOperation.addDependency($0) }

        return combiningOperation
    }

    func fetchEthBalance(for accountAddress: Data?,
                         runCompletionIn queue: DispatchQueue,
                         completionClosure: @escaping EthBalanceResultClosure) -> [Operation] {
        let operation = operationFactory.createEthBalanceFetchOperation(for: accountAddress)

        operation.completionBlock = {
            queue.async {
                completionClosure(operation.result)
            }
        }

        operationManager.enqueue(operations: [operation], in: executionMode)

        return [operation]
    }

    func fetchXORTokenBalance(for accountAddress: Data?,
                              runCompletionIn queue: DispatchQueue,
                              completionClosure: @escaping EthBalanceResultClosure) -> [Operation] {
        let tokenAddressOperation = operationFactory.createXORAddressFetchOperation(from: masterContractAddress)

        let config: EthAddressConfig = {
            guard let result = tokenAddressOperation.result else {
                throw BaseOperationError.parentOperationCancelled
            }

            switch result {
            case .success(let address):
                return address
            case .failure(let error):
                throw error
            }
        }

        let balanceOperation = operationFactory.createERC20TokenBalanceFetchOperation(from: config,
                                                                                      for: accountAddress)

        balanceOperation.addDependency(tokenAddressOperation)

        balanceOperation.completionBlock = {
            queue.async {
                completionClosure(balanceOperation.result)
            }
        }

        let operations: [Operation] = [tokenAddressOperation, balanceOperation]

        operationManager.enqueue(operations: operations, in: executionMode)

        return operations
    }

    func fetchTrasactionNonce(for accountAddress: Data?,
                              runCompletionIn queue: DispatchQueue,
                              completionClosure: @escaping EthBigUIntResultClosure) -> [Operation] {
        let operation = operationFactory.createTransactionsCountOperation(for: accountAddress,
                                                                          block: .pending)

        operation.completionBlock = {
            queue.async {
                completionClosure(operation.result)
            }
        }

        operationManager.enqueue(operations: [operation], in: executionMode)

        return [operation]
    }

    func checkWithdrawal(for hash: Data,
                         runCompletionIn queue: DispatchQueue,
                         completionClosure: @escaping EthBoolResultClosure) -> [Operation] {
        let operation = operationFactory.createWithdrawalCheckOperation(for: { hash },
                                                                        masterContractAddress: masterContractAddress)

        operation.completionBlock = {
            queue.async {
                completionClosure(operation.result)
            }
        }

        operationManager.enqueue(operations: [operation], in: executionMode)

        return [operation]
    }

    func withdraw(for config: @escaping EthWithdrawInfoConfig,
                  runCompletionIn queue: DispatchQueue,
                  completionClosure: @escaping EthDataResultClosure) -> [Operation] {
        let nonceOperation = operationFactory.createTransactionsCountOperation(with: .pending)

        let gasPriceOperation = operationFactory.createGasPriceOperation()

        let tokenAddressOperation = operationFactory.createXORAddressFetchOperation(from: masterContractAddress)

        let tokenAddressConfig: EthAddressConfig = {
            try tokenAddressOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }

        let withdrawTransactionOperation = operationFactory
            .createWithdrawTransactionOperation(for: config,
                                                tokenAddressConfig: tokenAddressConfig,
                                                masterContractAddress: masterContractAddress)

        withdrawTransactionOperation.addDependency(tokenAddressOperation)

        let transactionConfig: EthPreparedTransactionConfig = {
            try withdrawTransactionOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }

        let gasLimitOperation = operationFactory.createGasLimitOperation(for: transactionConfig)

        gasLimitOperation.addDependency(withdrawTransactionOperation)

        let transactionInfoConfig: EthReadyTransactionConfig = {
            let error = BaseOperationError.parentOperationCancelled
            let txData = try withdrawTransactionOperation.extractResultData(throwing: error)
            let gasPrice = try gasPriceOperation.extractResultData(throwing: error)
            let gasLimit = try gasLimitOperation.extractResultData(throwing: error)
            let nonce = try nonceOperation.extractResultData(throwing: error)

            return EthereumTransactionInfo(txData: txData, gasPrice: gasPrice, gasLimit: gasLimit, nonce: nonce)
        }

        let sendOperation = operationFactory.createSendTransactionOperation(for: transactionInfoConfig)

        sendOperation.addDependency(withdrawTransactionOperation)
        sendOperation.addDependency(gasPriceOperation)
        sendOperation.addDependency(gasLimitOperation)
        sendOperation.addDependency(nonceOperation)

        sendOperation.completionBlock = {
            queue.async {
                completionClosure(sendOperation.result)
            }
        }

        let operations = [
                nonceOperation,
                tokenAddressOperation,
                withdrawTransactionOperation,
                gasPriceOperation,
                gasLimitOperation,
                sendOperation
        ]

        operationManager.enqueue(operations: operations, in: executionMode)

        return operations
    }

    func transferERC20ToAddress(_ address: Data,
                                amount: BigUInt,
                                runCompletionIn queue: DispatchQueue,
                                completionClosure: @escaping EthDataResultClosure) -> [Operation] {
        let nonceOperation = operationFactory.createTransactionsCountOperation(with: .pending)

        let gasPriceOperation = operationFactory.createGasPriceOperation()

        let tokenAddressOperation = operationFactory.createXORAddressFetchOperation(from: masterContractAddress)

        let transferConfig: EthERC20TransferConfig = {
            let tokenAddress = try tokenAddressOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return ERC20TransferInfo(tokenAddress: tokenAddress,
                                     destinationAddress: address,
                                     amount: amount)
        }

        let transferOperation = operationFactory
            .createERC20TransferTransactionOperation(for: transferConfig)

        transferOperation.addDependency(tokenAddressOperation)

        let gasLimitConfig: EthPreparedTransactionConfig = {
            try transferOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }

        let gasLimitOperation = operationFactory.createGasLimitOperation(for: gasLimitConfig)

        gasLimitOperation.addDependency(transferOperation)

        let transactionInfoConfig: EthReadyTransactionConfig = {
            let error = BaseOperationError.parentOperationCancelled
            let txData = try transferOperation.extractResultData(throwing: error)
            let gasPrice = try gasPriceOperation.extractResultData(throwing: error)
            let gasLimit = try gasLimitOperation.extractResultData(throwing: error)
            let nonce = try nonceOperation.extractResultData(throwing: error)

            return EthereumTransactionInfo(txData: txData, gasPrice: gasPrice, gasLimit: gasLimit, nonce: nonce)
        }

        let sendOperation = operationFactory.createSendTransactionOperation(for: transactionInfoConfig)

        sendOperation.addDependency(nonceOperation)
        sendOperation.addDependency(gasPriceOperation)
        sendOperation.addDependency(gasLimitOperation)
        sendOperation.addDependency(transferOperation)

        sendOperation.completionBlock = {
            queue.async {
                completionClosure(sendOperation.result)
            }
        }

        let operations = [
                nonceOperation,
                tokenAddressOperation,
                transferOperation,
                gasPriceOperation,
                gasLimitOperation,
                sendOperation
        ]

        operationManager.enqueue(operations: operations, in: executionMode)

        return operations
    }

    @discardableResult
    func fetchTransactionByHash(_ transactionHash: Data,
                                runCompletionIn queue: DispatchQueue,
                                completionClosure: @escaping EthTransactionClosure) -> Operation {
        let operation = operationFactory.createTransactionByHashFetchOperation(transactionHash)

        operation.completionBlock = {
            queue.async {
                completionClosure(operation.result)
            }
        }

        operationManager.enqueue(operations: [operation], in: executionMode)

        return operation
    }
}
