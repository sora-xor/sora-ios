import Foundation
import RobinHood
import BigInt
import web3swift

typealias EthAddressConfig = () throws -> Data
typealias EthWithdrawHashConfig = () throws -> Data
typealias EthWithdrawInfoConfig  = () throws -> EthereumWithdrawInfo
typealias EthPreparedTransactionConfig = () throws -> Data
typealias EthReadyTransactionConfig = () throws -> EthereumTransactionInfo
typealias EthERC20TransferConfig = () throws -> ERC20TransferInfo
typealias EthBalanceResultClosure = (Result<BigUInt, Error>?) -> Void
typealias EthAddressResultClosure = (Result<Data, Error>?) -> Void
typealias EthBigUIntResultClosure = (Result<BigUInt, Error>?) -> Void
typealias EthBoolResultClosure = (Result<Bool, Error>?) -> Void
typealias EthVoidResultClosure = (Result<Void, Error>?) -> Void
typealias EthDataResultClosure = (Result<Data, Error>?) -> Void
typealias EthTransactionClosure = (Result<TransactionDetails?, Error>?) -> Void

struct EthereumServiceConstants {
    static let errorDomain = "EthereumDomain"
}

protocol EthereumServiceProtocol: BaseServiceProtocol {
    @discardableResult
    func fetchEthBalance(for accountAddress: Data?,
                         runCompletionIn queue: DispatchQueue,
                         completionClosure: @escaping EthBalanceResultClosure) -> [Operation]

    @discardableResult
    func fetchXORTokenBalance(for accountAddress: Data?,
                              runCompletionIn queue: DispatchQueue,
                              completionClosure: @escaping EthBalanceResultClosure) -> [Operation]

    @discardableResult
    func fetchTrasactionNonce(for accountAddress: Data?,
                              runCompletionIn queue: DispatchQueue,
                              completionClosure: @escaping EthBigUIntResultClosure) -> [Operation]

    @discardableResult
    func checkWithdrawal(for hash: Data,
                         runCompletionIn queue: DispatchQueue,
                         completionClosure: @escaping EthBoolResultClosure) -> [Operation]

    @discardableResult
    func withdraw(for config: @escaping EthWithdrawInfoConfig,
                  runCompletionIn queue: DispatchQueue,
                  completionClosure: @escaping EthDataResultClosure) -> [Operation]

    @discardableResult
    func transferERC20ToAddress(_ address: Data,
                                amount: BigUInt,
                                runCompletionIn queue: DispatchQueue,
                                completionClosure: @escaping EthDataResultClosure) -> [Operation]

    @discardableResult
    func fetchTransactionByHash(_ transactionHash: Data,
                                runCompletionIn queue: DispatchQueue,
                                completionClosure: @escaping EthTransactionClosure) -> Operation
}

extension EthereumServiceProtocol {
    func fetchEthBalance(runCompletionIn queue: DispatchQueue,
                         completionClosure: @escaping EthBalanceResultClosure) -> [Operation] {
        fetchEthBalance(for: nil, runCompletionIn: queue, completionClosure: completionClosure)
    }

    func fetchXORTokenBalance(runCompletionIn queue: DispatchQueue,
                              completionClosure: @escaping EthBalanceResultClosure) -> [Operation] {
        fetchXORTokenBalance(for: nil,
                             runCompletionIn: queue,
                             completionClosure: completionClosure)
    }
}

protocol EthereumOperationFactoryProtocol {
    func createEthBalanceFetchOperation(for accountAddress: Data?) -> BaseOperation<BigUInt>

    func createERC20TokenBalanceFetchOperation(from tokenAddressConfig: @escaping EthAddressConfig,
                                               for accountAddress: Data?) -> BaseOperation<BigUInt>

    func createXORAddressFetchOperation(from masterContractAddress: Data) -> BaseOperation<Data>

    func createGasLimitOperation(for transactionConfig: @escaping EthPreparedTransactionConfig)
        -> BaseOperation<BigUInt>

    func createGasPriceOperation() -> BaseOperation<BigUInt>

    func createTransactionsCountOperation(for accountAddress: Data?, block: EthereumBlock) -> BaseOperation<BigUInt>

    func createWithdrawalCheckOperation(for hashConfig: @escaping EthWithdrawHashConfig,
                                        masterContractAddress: Data) -> BaseOperation<Bool>

    func createWithdrawTransactionOperation(for withdrawInfoConfig: @escaping EthWithdrawInfoConfig,
                                            tokenAddressConfig: @escaping EthAddressConfig,
                                            masterContractAddress: Data) -> BaseOperation<Data>

    func createERC20TransferTransactionOperation(for config: @escaping EthERC20TransferConfig)
        -> BaseOperation<Data>

    func createSendTransactionOperation(for transactionInfoConfig: @escaping EthReadyTransactionConfig)
        -> BaseOperation<Data>

    func createTransactionByHashFetchOperation(_ transactionHash: Data)
        -> BaseOperation<TransactionDetails?>
}

extension EthereumOperationFactoryProtocol {
    func createEthBalanceFetchOperation() -> BaseOperation<BigUInt> {
        createEthBalanceFetchOperation(for: nil)
    }

    func createERC20TokenBalanceFetchOperation(from tokenAddressConfig: @escaping EthAddressConfig)
        -> BaseOperation<BigUInt> {
        createERC20TokenBalanceFetchOperation(from: tokenAddressConfig, for: nil)
    }

    func createTransactionsCountOperation(with block: EthereumBlock) -> BaseOperation<BigUInt> {
        createTransactionsCountOperation(for: nil, block: block)
    }
}
