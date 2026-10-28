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

import IrohaCrypto

extension WalletNetworkFacade {
    func createHistoryMergeOperation(
        dependingOn remoteOperation: BaseOperation<WalletRemoteHistoryData>?,
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        feeAsset: WalletAsset,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        let currentNetworkType = networkType
        let addressFactory = SS58AddressFactory()

        return ClosureOperation {
            let remoteTransactions = try remoteOperation?.extractNoCancellableResultData().historyItems ?? []

            if let localTransactions = try localOperation?.extractNoCancellableResultData()
                .filter({ $0.sender == address || $0.receiver == address }),
               !localTransactions.isEmpty {
                let manager = TransactionHistoryMergeManager(
                    address: address,
                    networkType: currentNetworkType,
                    asset: feeAsset,
                    addressFactory: addressFactory
                )
                return manager.merge(
                    remoteItems: remoteTransactions,
                    localItems: localTransactions
                )
            } else {
                let transactions: [AssetTransactionData] = remoteTransactions.compactMap { item in
                    item.createTransactionForAddress(
                        address,
                        networkType: currentNetworkType,
                        asset: feeAsset,
                        addressFactory: addressFactory
                    )
                }

                return TransactionHistoryMergeResult(
                    historyItems: transactions,
                    identifiersToRemove: []
                )
            }
        }
    }

    func createHistoryMapOperation(
        dependingOn mergeOperation: BaseOperation<TransactionHistoryMergeResult>,
        remoteOperation: BaseOperation<WalletRemoteHistoryData>
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let mergeResult = try mergeOperation.extractNoCancellableResultData()
            let newHistoryContext = try remoteOperation.extractNoCancellableResultData().context

            let contextDict = [TransactionHistoryContext.isComplete: String(newHistoryContext.isComplete),
                               TransactionHistoryContext.cursor: String(newHistoryContext.cursor ?? 1)]
            let context = !newHistoryContext.isComplete ? contextDict : nil
            
            return AssetTransactionPageData(
                transactions: mergeResult.historyItems.filter { self.assetManager.assetInfo(for: $0.assetId) != nil },
                context: context
            )
        }
    }
}
