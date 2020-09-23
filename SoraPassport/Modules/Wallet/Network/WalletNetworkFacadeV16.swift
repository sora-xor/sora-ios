/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood

typealias WalletNetworkInternalProtocolV16 = WalletNetworkOperationFactoryProtocol &
WalletRemoteHistoryOperationFactoryProtocol

final class WalletNetworkFacadeV16 {
    let soranetOperationFactory: WalletNetworkInternalProtocolV16

    init(soranetOperationFactory: WalletNetworkInternalProtocolV16) {
        self.soranetOperationFactory = soranetOperationFactory
    }
}

extension WalletNetworkFacadeV16: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        soranetOperationFactory.fetchBalanceOperation(assets)
    }

    func fetchTransactionHistoryOperation(_ filter: WalletHistoryRequest,
                                          pagination: Pagination)
        -> CompoundOperationWrapper<AssetTransactionPageData?> {
            let context: WalletHistoryContext

            if let paginationContext = pagination.context {
                context = paginationContext as WalletHistoryContext
            } else {
                context = WalletHistoryContext.initial
            }

            var dependencies: [Operation] = []

            var remoteFetch: CompoundOperationWrapper<MiddlewareTransactionPageData>?

            if let remoteOffset = context.remoteOffset {
                let remotePagination = OffsetPagination(offset: remoteOffset,
                                                        count: pagination.count)
                let wrapper = soranetOperationFactory
                        .fetchRemoteHistoryOperationForPagination(remotePagination)
                remoteFetch = wrapper
                dependencies.append(contentsOf: wrapper.allOperations)
            }

            let merge = WalletHistoryMergeOperation(size: pagination.count, context: context)
            merge.configurationBlock = {
                do {
                    if let remoteFetch = remoteFetch {
                        merge.remoteTransactions = try remoteFetch.targetOperation
                            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                            .transactions
                    }
                } catch {
                    merge.result = .failure(error)
                }
            }

            dependencies.forEach { merge.addDependency($0) }

            return CompoundOperationWrapper(targetOperation: merge, dependencies: dependencies)
    }

    func transferMetadataOperation(_ info: TransferMetadataInfo) -> CompoundOperationWrapper<TransferMetaData?> {
        soranetOperationFactory.transferMetadataOperation(info)
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        soranetOperationFactory.transferOperation(info)
    }

    func searchOperation(_ searchString: String) -> CompoundOperationWrapper<[SearchData]?> {
        soranetOperationFactory.searchOperation(searchString)
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        soranetOperationFactory.contactsOperation()
    }

    func withdrawalMetadataOperation(_ info: WithdrawMetadataInfo) -> CompoundOperationWrapper<WithdrawMetaData?> {
        soranetOperationFactory.withdrawalMetadataOperation(info)
    }

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        soranetOperationFactory.withdrawOperation(info)
    }
}
