// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import RobinHood
import sorawallet

final class HistoryPage {
    let transactions: [Transaction]
    let errorMessage: String?
    let endReached: Bool
    
    init(transactions: [Transaction], endReached: Bool, errorMessage: String? = nil) {
        self.transactions = transactions
        self.endReached = endReached
        self.errorMessage = errorMessage
    }
}

protocol HistoryServiceProtocol {
    func getHistory(count: Int, assetId: String?, completion: @escaping (Result<[Transaction], Swift.Error>) -> Void)
    func getPageHistory(count: Int, page: Int, assetId: String?, completion: @escaping (Result<HistoryPage, Swift.Error>) -> Void)
    func getTransaction(by txHash: String) -> Transaction?
    func getHistory(count: Int, assetId: String?) async throws -> [Transaction]
    func getPageHistory(count: Int, page: Int, assetId: String?) async throws -> HistoryPage
}

final class HistoryService {

    private var address: String
    private let operationManager: OperationManager
    private let historyMapper: HistoryTransactionMapperProtocol
    private var transactions: [Transaction] = []
    private var localStorage: LocalTransactionStorageProtocol = LocalTransactionStorage.shared
    
    init(operationManager: OperationManager, address: String, assets: [AssetInfo]) {
        self.operationManager = operationManager
        self.address = address
        self.historyMapper = HistoryTransactionMapper(myAddress: address, assets: assets)
    }
}

extension HistoryService: HistoryServiceProtocol {
    @available(*, renamed: "getHistory(count:assetId:)")
    func getHistory(count: Int, assetId: String?, completion: @escaping (Result<[Transaction], Swift.Error>) -> Void) {
        Task {
            do {
                let result = try await getHistory(count: count, assetId: assetId)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    
    func getHistory(count: Int, assetId: String?) async throws -> [Transaction] {
        let filter1: ((TxHistoryItem) -> KotlinBoolean)? = assetId != nil ? { item in
            let callPath = KmmCallCodingPath(moduleName: item.module, callName: item.method)
            
            if callPath.isTransfer {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "assetId" }?.paramValue == assetId)
            }
            
            if callPath == KmmCallCodingPath.bondReferralBalance ||
                callPath == KmmCallCodingPath.unbondReferralBalance ||
                callPath == KmmCallCodingPath.setReferral {
                return KotlinBoolean(value:assetId == WalletAssetId.xor.rawValue)
            }
            
            if callPath.isSwap {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "baseAssetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "targetAssetId" }?.paramValue == assetId)
            }
            
            if callPath.isDepositLiquidity || callPath.isWithdrawLiquidity {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "baseAssetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "targetAssetId" }?.paramValue == assetId)
            }
            
            if callPath == KmmCallCodingPath.batchUtility || callPath == KmmCallCodingPath.batchAllUtility {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "input_asset_a" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "input_asset_b" }?.paramValue == assetId)
            }
            
            if callPath.isClaimReward {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "assetId" }?.paramValue == assetId)
            }
            
            if callPath.isDepositFarmLiquidity || callPath.isWithdrawFarmLiquidity {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "assetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "baseAssetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "rewardAssetId" }?.paramValue == assetId)
            }
            
            return KotlinBoolean(value: false)
        } : nil
        
        let queryOperation = SubqueryHistoryOperation<TxHistoryResult<TxHistoryItem>>(address: address,
                                                                                      count: count,
                                                                                      page: 1,
                                                                                      filter: filter1)
        operationManager.enqueue(operations: [queryOperation], in: .transient)
        
        return try await withCheckedThrowingContinuation { continuation in
            queryOperation.completionBlock = { [weak self] in
                do {
                    guard let self1 = self, let address = SelectedWalletSettings.shared.currentAccount?.address else { return }
                    let response = try queryOperation.extractNoCancellableResultData()
                    let remoteTransactions: [Transaction] = try self1.historyMapper.map(items: response.items as? [TxHistoryItem] ?? []).compactMap { $0 }
                    let localTransaction = self1.localStorage.transactions[address] ?? []
                    
                    let existingHashes = Set(remoteTransactions.map { $0.base.txHash })
                    
                    let hashesToRemove: [String] = localTransaction.compactMap { item in
                        if existingHashes.contains(item.base.txHash) {
                            return item.base.txHash
                        }
                        return nil
                    }
                    
                    let filterSet = Set(hashesToRemove)
                    let localMergeItems: [Transaction] = localTransaction.filter { !filterSet.contains($0.base.txHash) }
                    
                    let transactionsItems = (localMergeItems + remoteTransactions).sorted(by: { item1, item2 in
                        Int64(item1.base.timestamp) ?? 0 > Int64(item2.base.timestamp) ?? 0
                    })
                    
                    continuation.resume(with: .success(transactionsItems))
                    
                    transactionsItems.forEach { transaction in
                        if !self1.transactions.map({ $0.base.txHash }).contains(transaction.base.txHash) {
                            self1.transactions.append(transaction)
                        }
                    }
                } catch let error {
                    continuation.resume(with: .failure(error))
                }
            }
        }
    }
    
    @available(*, renamed: "getPageHistory(count:page:assetId:)")
    func getPageHistory(count: Int, page: Int, assetId: String?, completion: @escaping (Result<HistoryPage, Swift.Error>) -> Void) {
        Task {
            do {
                let result = try await getPageHistory(count: count, page: page, assetId: assetId)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    
    func getPageHistory(count: Int, page: Int, assetId: String?) async throws -> HistoryPage {
        let filter1: ((TxHistoryItem) -> KotlinBoolean)? = assetId != nil ? { item in
            let callPath = KmmCallCodingPath(moduleName: item.module, callName: item.method)
            
            if callPath.isTransfer {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "assetId" }?.paramValue == assetId)
            }
            
            if callPath == KmmCallCodingPath.bondReferralBalance ||
                callPath == KmmCallCodingPath.unbondReferralBalance ||
                callPath == KmmCallCodingPath.setReferral {
                return KotlinBoolean(value:assetId == WalletAssetId.xor.rawValue)
            }
            
            if callPath.isSwap {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "baseAssetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "targetAssetId" }?.paramValue == assetId)
            }
            
            if callPath.isDepositLiquidity || callPath.isWithdrawLiquidity {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "baseAssetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "targetAssetId" }?.paramValue == assetId)
            }
            
            if callPath == KmmCallCodingPath.batchUtility || callPath == KmmCallCodingPath.batchAllUtility {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "input_asset_a" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "input_asset_b" }?.paramValue == assetId)
            }
            
            if callPath.isClaimReward {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "assetId" }?.paramValue == assetId)
            }
            
            if callPath.isDepositFarmLiquidity || callPath.isWithdrawFarmLiquidity {
                return KotlinBoolean(value: item.data?.first { $0.paramName == "assetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "baseAssetId" }?.paramValue == assetId ||
                                     item.data?.first { $0.paramName == "rewardAssetId" }?.paramValue == assetId)
            }
            
            return KotlinBoolean(value: false)
        } : nil
        
        let queryOperation = SubqueryHistoryOperation<TxHistoryResult<TxHistoryItem>>(address: address,
                                                                                      count: count,
                                                                                      page: page,
                                                                                      filter: filter1)
        
        return try await withCheckedThrowingContinuation { continuation in
            queryOperation.completionBlock = { [weak self] in
                do {
                    guard let self, let address = SelectedWalletSettings.shared.currentAccount?.address else { return }
                    let response = try queryOperation.extractNoCancellableResultData()
                    let remoteTransactions: [Transaction] = try self.historyMapper.map(items: response.items as? [TxHistoryItem] ?? []).compactMap { $0 }
                    let localTransaction = page == 1 ? (self.localStorage.transactions[address] ?? []) : []
                    let existingHashes = Set(remoteTransactions.map { $0.base.txHash })
                    
                    let hashesToRemove: [String] = localTransaction.compactMap { item in
                        if existingHashes.contains(item.base.txHash) {
                            return item.base.txHash
                        }
                        return nil
                    }
                    
                    let filterSet = Set(hashesToRemove)
                    let localMergeItems: [Transaction] = localTransaction.filter { !filterSet.contains($0.base.txHash) }
                    
                    let transactionsItems = (localMergeItems + remoteTransactions).sorted(by: { item1, item2 in
                        Float(item1.base.timestamp) ?? 0 > Float(item2.base.timestamp) ?? 0
                    })
                    
                    let endReached = response.errorMessage != nil ? true : response.endReached
                    continuation.resume(with: .success(HistoryPage(transactions: transactionsItems, endReached: endReached, errorMessage: response.errorMessage)))
                    
                    transactionsItems.forEach { transaction in
                        if !self.transactions.map({ $0.base.txHash }).contains(transaction.base.txHash) {
                            self.transactions.append(transaction)
                        }
                    }
                } catch let error {
                    continuation.resume(with: .failure(error))
                }
            }
            
            operationManager.enqueue(operations: [queryOperation], in: .transient)
        }
    }
    
    func getTransaction(by txHash: String) -> Transaction? {
        return transactions.first { $0.base.txHash == txHash }
    }
}
