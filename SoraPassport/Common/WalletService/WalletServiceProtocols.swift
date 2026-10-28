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

typealias BalanceCompletionBlock = (Result<[BalanceData]?, Error>?) -> Void
typealias TransactionHistoryBlock = (Result<AssetTransactionPageData?, Error>?) -> Void
typealias EmptyResultCompletionBlock = (Result<Void, Error>?) -> Void
typealias DataResultCompletionBlock = (Result<Data, Error>?) -> Void
typealias SearchCompletionBlock = (Result<[SearchData]?, Error>?) -> Void
typealias WithdrawalMetadataCompletionBlock = (Result<WithdrawMetaData?, Error>?) -> Void
typealias TransferMetadataCompletionBlock = (Result<TransferMetaData?, Error>?) -> Void

protocol WalletServiceProtocol {
    
    @discardableResult
    func fetchBalance(for assets: [String],
                      runCompletionIn queue: DispatchQueue,
                      completionBlock: @escaping BalanceCompletionBlock) -> CancellableCall

    @discardableResult
    func fetchTransactionHistory(for filter: WalletHistoryRequest,
                                 pagination: Pagination,
                                 runCompletionIn queue: DispatchQueue,
                                 completionBlock: @escaping TransactionHistoryBlock) -> CancellableCall

    @discardableResult
    func fetchTransferMetadata(for info: TransferMetadataInfo,
                               runCompletionIn queue: DispatchQueue,
                               completionBlock: @escaping TransferMetadataCompletionBlock)
        -> CancellableCall

    @discardableResult
    func transfer(info: TransferInfo,
                  runCompletionIn queue: DispatchQueue,
                  completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall

    func prepareTransferSubmission(
        for info: TransferInfo,
        preSigningValidation: @escaping () throws -> Void
    ) async throws -> PreparedSora2TransferSubmission

    func submitPreparedTransfer(
        _ submission: PreparedSora2TransferSubmission,
        info: TransferInfo,
        preTransportValidation: @escaping () throws -> Void
    ) async throws -> Data

    @discardableResult
    func search(for searchString: String,
                runCompletionIn queue: DispatchQueue,
                completionBlock: @escaping SearchCompletionBlock) -> CancellableCall
    
    @discardableResult
    func fetchContacts(runCompletionIn queue: DispatchQueue,
                       completionBlock: @escaping SearchCompletionBlock) -> CancellableCall

    @discardableResult
    func fetchWithdrawalMetadata(for info: WithdrawMetadataInfo,
                                 runCompletionIn queue: DispatchQueue,
                                 completionBlock: @escaping WithdrawalMetadataCompletionBlock)
        -> CancellableCall

    @discardableResult
    func withdraw(info: WithdrawInfo,
                  runCompletionIn queue: DispatchQueue,
                  completionBlock: @escaping DataResultCompletionBlock) -> CancellableCall
}
