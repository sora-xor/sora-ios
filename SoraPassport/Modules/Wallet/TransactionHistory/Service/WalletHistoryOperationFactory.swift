/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood

protocol WalletHistoryOperationFactoryProtocol {
    func fetchHistoryOperationForPagination(_ pagination: Pagination)
        -> CompoundOperationWrapper<AssetTransactionPageData?>
}

final class WalletHistoryOperationFactory {
    let remoteOperationFactory: WalletRemoteHistoryOperationFactoryProtocol
    let transferRepository: AnyDataProviderRepository<TransferOperationData>
    let withdrawRepository: AnyDataProviderRepository<WithdrawOperationData>
    let depositRepository: AnyDataProviderRepository<DepositOperationData>

    init(networkOperationFactory: WalletRemoteHistoryOperationFactoryProtocol,
         transferRepository: AnyDataProviderRepository<TransferOperationData>,
         withdrawRepository: AnyDataProviderRepository<WithdrawOperationData>,
         depositRepository: AnyDataProviderRepository<DepositOperationData>) {
        self.remoteOperationFactory = networkOperationFactory
        self.transferRepository = transferRepository
        self.withdrawRepository = withdrawRepository
        self.depositRepository = depositRepository
    }
}

extension WalletHistoryOperationFactory: WalletHistoryOperationFactoryProtocol {
    func fetchHistoryOperationForPagination(_ pagination: Pagination)
        -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let context: WalletHistoryContext

        if let paginationContext = pagination.context {
            context = paginationContext as WalletHistoryContext
        } else {
            context = WalletHistoryContext.initial
        }

        let fetchOptions = RepositoryFetchOptions()

        var dependencies: [Operation] = []

        var remoteFetch: CompoundOperationWrapper<MiddlewareTransactionPageData>?

        if let remoteOffset = context.remoteOffset {
            let remotePagination = OffsetPagination(offset: remoteOffset,
                                                    count: pagination.count)
            let wrapper = remoteOperationFactory
                    .fetchRemoteHistoryOperationForPagination(remotePagination)
            remoteFetch = wrapper
            dependencies.append(contentsOf: wrapper.allOperations)
        }

        var transfersFetch: BaseOperation<[TransferOperationData]>?

        if let transferOffset = context.transferOffset {
            let transfersRequest = RepositorySliceRequest(offset: transferOffset,
                                                          count: pagination.count,
                                                          reversed: false)
            let operation = transferRepository.fetchOperation(by: transfersRequest,
                                                              options: fetchOptions)
            transfersFetch = operation
            dependencies.append(operation)
        }

        var withdrawsFetch: BaseOperation<[WithdrawOperationData]>?

        if let withdrawOffset = context.withdrawOffset {
            let withdrawRequest = RepositorySliceRequest(offset: withdrawOffset,
                                                         count: pagination.count,
                                                         reversed: false)
            let operation = withdrawRepository.fetchOperation(by: withdrawRequest,
                                                              options: fetchOptions)
            withdrawsFetch = operation
            dependencies.append(operation)
        }

        var depositFetch: BaseOperation<[DepositOperationData]>?

        if let depositOffset = context.depositOffset {
            let depositRequest = RepositorySliceRequest(offset: depositOffset,
                                                        count: pagination.count,
                                                        reversed: false)
            let operation = depositRepository.fetchOperation(by: depositRequest,
                                                             options: fetchOptions)
            depositFetch = operation
            dependencies.append(operation)
        }

        let merge = WalletHistoryMergeOperation(size: pagination.count, context: context)
        merge.configurationBlock = {
            do {
                if let remoteFetch = remoteFetch {
                    merge.remoteTransactions = try remoteFetch.targetOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                        .transactions
                }

                if let transfersFetch = transfersFetch {
                    merge.transfers = try transfersFetch
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                }

                if let withdrawsFetch = withdrawsFetch {
                    merge.withdraws = try withdrawsFetch
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                }

                if let depositsFetch = depositFetch {
                    merge.deposits = try depositsFetch
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                }
            } catch {
                merge.result = .failure(error)
            }
        }

        dependencies.forEach { merge.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: merge, dependencies: dependencies)
    }
}
