/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import XNetworking

extension SubqueryHistoryOperationFactory: WalletRemoteHistoryFactoryProtocol {
    func createOperationWrapper(
        for context: TransactionHistoryContext,
        address: String,
        count: Int
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        let queryOperation = SubqueryHistoryOperation<TxHistoryResult<TxHistoryItem>>(address: address,
                                                                           count: count,
                                                                           page: context.cursor ?? 1)

        let mappingOperation = ClosureOperation<WalletRemoteHistoryData> {
            guard let response = try? queryOperation.extractNoCancellableResultData()
            else {
                return WalletRemoteHistoryData(historyItems: [], context: TransactionHistoryContext(context: [:]))
            }

            let items = (response.items as? [WalletRemoteHistoryItemProtocol]) ?? []
            let cursor = (context.cursor ?? 1) + 1
            
            let context = TransactionHistoryContext(
                cursor: cursor,
                isComplete: response.endReached
            )

            return WalletRemoteHistoryData(
                historyItems: items,
                context: context
            )
        }

        mappingOperation.addDependency(queryOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [queryOperation])
    }
}
