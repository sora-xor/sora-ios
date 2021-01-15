/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood
import BigInt

final class WalletNetworkFacade {
    let soranetOperationFactory: WalletNetworkOperationFactoryProtocol
    let ethereumOperationFactory: EthereumOperationFactoryProtocol
    let transferRepository: AnyDataProviderRepository<TransferOperationData>
    let withdrawRepository: AnyDataProviderRepository<WithdrawOperationData>
    let depositRepository: AnyDataProviderRepository<DepositOperationData>
    let historyOperationFactory: WalletHistoryOperationFactoryProtocol
    let soranetAccountId: String
    let ethereumAddress: Data
    let masterContractAddress: Data
    let xorAssetId: String
    let valAssetId: String
    let ethAssetId: String

    init(soranetOperationFactory: WalletNetworkOperationFactoryProtocol,
         ethereumOperationFactory: EthereumOperationFactoryProtocol,
         transferRepository: AnyDataProviderRepository<TransferOperationData>,
         withdrawRepository: AnyDataProviderRepository<WithdrawOperationData>,
         depositRepository: AnyDataProviderRepository<DepositOperationData>,
         historyOperationFactory: WalletHistoryOperationFactoryProtocol,
         soranetAccountId: String,
         ethereumAddress: Data,
         masterContractAddress: Data,
         xorAssetId: String,
         valAssetId: String,
         ethAssetId: String) {
        self.soranetOperationFactory = soranetOperationFactory
        self.ethereumOperationFactory = ethereumOperationFactory
        self.transferRepository = transferRepository
        self.withdrawRepository = withdrawRepository
        self.depositRepository = depositRepository
        self.historyOperationFactory = historyOperationFactory
        self.soranetAccountId = soranetAccountId
        self.ethereumAddress = ethereumAddress
        self.masterContractAddress = masterContractAddress
        self.xorAssetId = xorAssetId
        self.valAssetId = valAssetId
        self.ethAssetId = ethAssetId
    }
}

extension WalletNetworkFacade: WalletNetworkOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(_ filter: WalletHistoryRequest,
                                          pagination: Pagination)
        -> CompoundOperationWrapper<AssetTransactionPageData?> {
        historyOperationFactory.fetchHistoryOperationForPagination(pagination)
    }

    func transferMetadataOperation(_ info: TransferMetadataInfo) -> CompoundOperationWrapper<TransferMetaData?> {
        if NSPredicate.ethereumAddress.evaluate(with: info.receiver) {
            return createEthereumReceiverMetadata(for: info)
        } else {
            return createSoranetReceiverMetadata(for: info)
        }
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        if NSPredicate.ethereumAddress.evaluate(with: info.destination) {
            return transferToEthereumOperation(info)
        } else {
            return transferToSoranetOperation(info)
        }
    }

    func searchOperation(_ searchString: String) -> CompoundOperationWrapper<[SearchData]?> {
        soranetOperationFactory.searchOperation(searchString)
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        soranetOperationFactory.contactsOperation()
    }

    func withdrawalMetadataOperation(_ info: WithdrawMetadataInfo)
        -> CompoundOperationWrapper<WithdrawMetaData?> {
            soranetOperationFactory.withdrawalMetadataOperation(info)
    }

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        soranetOperationFactory.withdrawOperation(info)
    }

    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        let balanceWrapper: CompoundOperationWrapper<TokenBalancesData>?

        var dependencies: [Operation] = []

        if assets.contains(valAssetId) {
            let wrapper = createXORBalanceOperationWrapper()
            dependencies.append(contentsOf: wrapper.allOperations)
            balanceWrapper = wrapper
        } else {
            balanceWrapper = nil
        }

        let ethOperation: BaseOperation<BigUInt>?

        if assets.contains(ethAssetId) {
            let operation = ethereumOperationFactory.createEthBalanceFetchOperation()
            dependencies.append(operation)
            ethOperation = operation
        } else {
            ethOperation = nil
        }

        let combiningOperation: BaseOperation<[BalanceData]?> = ClosureOperation {
            var balances: [BalanceData] = []

            if let xorBalanceWrapper = balanceWrapper {
                let tokens = try xorBalanceWrapper.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                let totalValue = tokens.soranet + tokens.ethereum

                let context: [String: String] = [
                    WalletOperationContextKey.Balance.soranet: tokens.soranet.stringWithPointSeparator,
                    WalletOperationContextKey.Balance.erc20: tokens.ethereum.stringWithPointSeparator
                ]

                let balance = BalanceData(identifier: self.valAssetId,
                                          balance: AmountDecimal(value: totalValue),
                                          context: context)

                balances.append(balance)
            }

            if let ethOperation = ethOperation {
                let ethValue = try ethOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                guard let ethDecimal = Decimal.fromEthereumAmount(ethValue) else {
                    throw WalletNetworkFacadeError.brokenAmountValue
                }

                let balance = BalanceData(identifier: self.ethAssetId,
                                          balance: AmountDecimal(value: ethDecimal))
                balances.append(balance)
            }

            return balances
        }

        dependencies.forEach { combiningOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: combiningOperation,
                                        dependencies: dependencies)
    }
}
