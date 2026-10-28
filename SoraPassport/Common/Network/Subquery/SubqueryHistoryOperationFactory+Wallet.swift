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
import sorawallet

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
