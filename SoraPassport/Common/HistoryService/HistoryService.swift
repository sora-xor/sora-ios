import Foundation
import RobinHood
import XNetworking

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
    func getHistory(count: Int, assetId: String?, completion: @escaping (Result<[Transaction], Swift.Error>) -> Void) {
        let filter: ((TxHistoryItem) -> KotlinBoolean)? = assetId != nil ? { item in
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
            
            return KotlinBoolean(value: false)
        } : nil
        
        let queryOperation = SubqueryHistoryOperation<TxHistoryResult<TxHistoryItem>>(address: address,
                                                                                      count: count,
                                                                                      page: 1,
                                                                                      filter: filter)

        queryOperation.completionBlock = { [weak self] in
            do {
                guard let self = self, let address = SelectedWalletSettings.shared.currentAccount?.address else { return }
                let response = try queryOperation.extractNoCancellableResultData()
                let remoteTransactions: [Transaction] = self.historyMapper.map(items: response.items as? [TxHistoryItem] ?? []).compactMap { $0 }
                let localTransaction = self.localStorage.transactions[address] ?? []
                
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
                
                completion(.success(transactionsItems))
                
                transactionsItems.forEach { transaction in
                    if !self.transactions.map({ $0.base.txHash }).contains(transaction.base.txHash) {
                        self.transactions.append(transaction)
                    }
                }
            } catch let error {
                completion(.failure(error))
            }
        }
        
        operationManager.enqueue(operations: [queryOperation], in: .transient)
    }
    
    func getPageHistory(count: Int, page: Int, assetId: String?, completion: @escaping (Result<HistoryPage, Swift.Error>) -> Void) {
        let filter: ((TxHistoryItem) -> KotlinBoolean)? = assetId != nil ? { item in
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
            
            return KotlinBoolean(value: false)
        } : nil
        
        let queryOperation = SubqueryHistoryOperation<TxHistoryResult<TxHistoryItem>>(address: address,
                                                                                      count: count,
                                                                                      page: page,
                                                                                      filter: filter)

        queryOperation.completionBlock = { [weak self] in
            do {
                guard let self = self, let address = SelectedWalletSettings.shared.currentAccount?.address else { return }
                let response = try queryOperation.extractNoCancellableResultData()
                let remoteTransactions: [Transaction] = self.historyMapper.map(items: response.items as? [TxHistoryItem] ?? []).compactMap { $0 }
                let localTransaction = self.localStorage.transactions[address] ?? []
                
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
                completion(.success(HistoryPage(transactions: transactionsItems, endReached: endReached, errorMessage: response.errorMessage)))
                
                transactionsItems.forEach { transaction in
                    if !self.transactions.map({ $0.base.txHash }).contains(transaction.base.txHash) {
                        self.transactions.append(transaction)
                    }
                }
            } catch let error {
                completion(.failure(error))
            }
        }
        
        operationManager.enqueue(operations: [queryOperation], in: .transient)
    }
    
    func getTransaction(by txHash: String) -> Transaction? {
        return transactions.first { $0.base.txHash == txHash }
    }
}
