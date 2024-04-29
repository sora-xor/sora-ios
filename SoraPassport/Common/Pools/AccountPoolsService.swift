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

import SSFUtils
import RobinHood
import sorawallet
import SSFStorageQueryKit

protocol PoolsServiceInputProtocol: AnyObject {
    func loadAccountPools()
    func getAccountPools() -> [PoolInfo]
    func updatePools(_ pools: [PoolInfo])
    func getPool(by id: String) -> PoolInfo?
    func getPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo?
    func loadPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo?
    func loadPools(currentAsset: AssetInfo) -> [PoolInfo]
    func loadTargetPools(for baseAssetId: String) -> [PoolInfo]
    func appendDelegate(delegate: PoolsServiceOutput)
    
    func isPairEnabled(
        baseAssetId: String,
        targetAssetId: String,
        accountId: String,
        completion: @escaping (Bool) -> Void)
    
    func isPairPresentedInNetwork(
        baseAssetId: String,
        targetAssetId: String,
        accountId: String,
        completion: @escaping (Bool) -> Void)
}

protocol PoolsServiceOutput: AnyObject {
    func loaded(pools: [PoolInfo])
}

final class AccountPoolsService {
    
    struct PoolsChanges {
        let newOrUpdatedItems: [PoolInfo]
        let removedItems: [PoolInfo]
    }

    var outputs: [WeakWrapper] = []
    var networkFacade: WalletNetworkOperationFactoryProtocol?
    var polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?
    let operationManager: OperationManagerProtocol = OperationManager()
    
    var subscriptionIds: [UInt16] = []
    var subscriptionUpdates: [String: String] = [:]
    private let config: ApplicationConfigProtocol
    private let poolRepository: AnyDataProviderRepository<PoolInfo>
    private var currentPools: [PoolInfo] = []
    private var polkaswapOperationFactory: PolkaswapNetworkOperationFactoryProtocol
    private var task: Task<Void, Swift.Error>?
    
    var currentOrder: [String] {
        get {
            return UserDefaults.standard.array(forKey: "poolsOrder") as? [String] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "poolsOrder")
        }
    }
    
    init(
        operationManager: OperationManagerProtocol,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
        config: ApplicationConfigProtocol
        
    ) {
        self.networkFacade = networkFacade
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.config = config
        
        let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())
        self.polkaswapOperationFactory = PolkaswapNetworkOperationFactory(engine: connection!)
        
        self.poolRepository = AnyDataProviderRepository(PoolRepositoryFactory().createRepository())
        
        setup()
    }
    
    func setup() {
        unsubscribePoolsReserves()
        subscribeAccountPool(baseAssetId: WalletAssetId.xor.rawValue)
        subscribeAccountPool(baseAssetId: WalletAssetId.xstusd.rawValue)
        loadAccountPools()
    }
    
    func subscribeAccountPool(baseAssetId: String) {
        do {
            guard let accountId = (networkFacade as? WalletNetworkFacade)?.address.accountId,
                  let baseAssetIdData = try? Data(hexStringSSF: baseAssetId) else { return }
            let storageKey = try StorageKeyFactory()
                .accountPoolsKeyForId(accountId, baseAssetId: baseAssetIdData)
                .toHex(includePrefix: true)
            
            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { update in
                Task { [weak self] in
                    guard let self, let assetIds = try? await self.decodeCodes(with: update) else { return }
                    assetIds.forEach { targetAssetId in
                        self.subscribePoolReserves(baseAsset: baseAssetId, targetAsset: targetAssetId)
                    }
                }
            }
            
            let subscriptionId = try polkaswapNetworkFacade!.engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: { _, _ in })
            subscriptionIds.append(subscriptionId)
        } catch {
            print("Can't subscribe to storage:  \(error)")
        }
    }
    
    private func decodeCodes(with update: JSONRPCSubscriptionUpdate<StorageUpdate>) async throws -> [String] {
        let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash())
        let fetchCoderFactoryOperation = runtimeService!.fetchCoderFactoryOperation()
        
        let decodingOperation = StorageFallbackDecodingListOperation<[AssetId]>(path: .userPools)
        decodingOperation.addDependency(fetchCoderFactoryOperation)
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try fetchCoderFactoryOperation.extractNoCancellableResultData()
                decodingOperation.dataList = StorageUpdateData(update: update.params.result).changes.map(\.value)
            } catch {
                decodingOperation.result = .failure(error)
            }
        }
        operationManager.enqueue(operations: [fetchCoderFactoryOperation, decodingOperation], in: .transient)
        
        return try await withCheckedThrowingContinuation { continuetion in
            decodingOperation.completionBlock = {
                do {
                    guard let result = try decodingOperation.extractNoCancellableResultData().first, let result else {
                        continuetion.resume(returning: [])
                        return
                    }
                    
                    let assetIds = result.map { $0.value }
                    continuetion.resume(returning: assetIds)
                } catch {
                    print("Decoding error \(error)")
                }
            }
        }
    }
    
    func subscribePoolReserves(baseAsset: String, targetAsset: String) {
        do {
            let storageKey = try StorageKeyFactory()
                .poolReservesKey(baseAssetId: Data(hex: baseAsset), targetAssetId: Data(hex: targetAsset))
                .toHex(includePrefix: true)
            
            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in
                guard let weakSelf = self else { return }
                let key = baseAsset + targetAsset
                if weakSelf.subscriptionUpdates[key] == nil {
                    // first call during subscription; ignore
                    weakSelf.subscriptionUpdates[key] = update.params.result.blockHash
                } else {
                    weakSelf.loadAccountPools()
                }
            }
            
            let subscriptionId = try polkaswapNetworkFacade!.engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: { _, _ in })
            subscriptionIds.append(subscriptionId)
        } catch {
            print("Can't subscribe to storage:  \(error)")
        }
    }
    
    func unsubscribePoolsReserves() {
        subscriptionIds.forEach({
            polkaswapNetworkFacade?.engine.cancelForIdentifier($0)
        })
        subscriptionIds = []
        subscriptionUpdates = [:]
    }
}

extension AccountPoolsService: PoolsServiceInputProtocol {
    func appendDelegate(delegate: PoolsServiceOutput) {
        let weakDelegate = WeakWrapper(target: delegate)
        outputs.append(weakDelegate)
    }
    
    func getPool(by id: String) -> PoolInfo? {
        return currentPools.first { $0.poolId == id }
    }
    
    func getPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo? {
        if let localPool = currentPools.first(where: { $0.targetAssetId == targetAssetId && $0.baseAssetId == baseAssetId }) {
            return localPool
        }
        
        return await loadPool(by: baseAssetId, targetAssetId: targetAssetId)
    }
    
    func loadPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo? {
        guard let poolDetails = try? await (networkFacade as? WalletNetworkFacade)?.getPoolDetails(
            baseAsset: baseAssetId,
            targetAsset: targetAssetId
        ) else { return nil }
        
        return PoolInfo(
            baseAssetId: poolDetails.baseAsset,
            targetAssetId: poolDetails.targetAsset,
            poolId: "",
            isFavorite: false,
            accountId: "",
            yourPoolShare: poolDetails.yourPoolShare,
            baseAssetPooledByAccount: poolDetails.baseAssetPooledByAccount,
            targetAssetPooledByAccount: poolDetails.targetAssetPooledByAccount,
            baseAssetPooledTotal: poolDetails.baseAssetPooledTotal,
            targetAssetPooledTotal: poolDetails.targetAssetPooledTotal,
            totalIssuances: poolDetails.totalIssuances,
            baseAssetReserves: poolDetails.baseAssetReserves,
            targetAssetReserves: poolDetails.targetAssetReserves,
            accountPoolBalance: poolDetails.accountPoolBalance,
            farms: poolDetails.farms
        )
    }
    
    func checkIsPairExists(baseAsset: String, targetAsset: String, completion: @escaping (Bool) -> Void) {
        let dexId = polkaswapOperationFactory.dexId(for: baseAsset)
        let operation = polkaswapOperationFactory.isPairEnabled(
            dexId: dexId,
            assetId: baseAsset,
            tokenAddress: targetAsset
        )
        operation.completionBlock = {
            DispatchQueue.main.async {
                let isAvailable = ( try? operation.extractResultData() ) ?? false
                completion(isAvailable)
            }
        }
        operationManager.enqueue(operations: [operation], in: .blockAfter)
    }
    
    func loadPools(currentAsset: AssetInfo) -> [PoolInfo] {
        return currentPools.filter { $0.baseAssetId == currentAsset.assetId || $0.targetAssetId == currentAsset.assetId }
    }
    
    func loadTargetPools(for baseAssetId: String) -> [PoolInfo] {
        return currentPools.filter { $0.baseAssetId == baseAssetId }
    }
    
    func getAccountPools() -> [PoolInfo] {
        return currentPools.sorted(by: orderSort)
    }
    
    func loadAccountPools() {
        Task {
            guard let fetchRemotePoolsOperation = try? (networkFacade as? WalletNetworkFacade)?.getAccountPoolsDetails() else { return }
            let fetchOperation = poolRepository.fetchAllOperation(with: RepositoryFetchOptions())
            
            let processingOperation: BaseOperation<PoolsChanges> = ClosureOperation { [weak self] in
                guard let self = self else { return PoolsChanges(newOrUpdatedItems: [], removedItems: []) }
                let localPools = try fetchOperation.extractNoCancellableResultData()
                let remotePoolDetails = (try? fetchRemotePoolsOperation.targetOperation.extractResultData()) ?? []
                let accountId = (self.networkFacade as? WalletNetworkFacade)?.accountSettings.accountId ?? ""

                let remotePoolInfo = remotePoolDetails.enumerated().map { (index, poolDetail) -> PoolInfo in
                    let idData = NSMutableData()
                    idData.append(Data(poolDetail.baseAsset.utf8))
                    idData.append(Data(poolDetail.targetAsset.utf8))
                    idData.append(Data(accountId.utf8))
                    let poolId = String(idData.hashValue)
                    
                    return PoolInfo(baseAssetId: poolDetail.baseAsset,
                                    targetAssetId: poolDetail.targetAsset,
                                    poolId: poolId,
                                    isFavorite: localPools.first { $0.poolId == poolId }?.isFavorite ?? true,
                                    accountId: accountId,
                                    yourPoolShare: poolDetail.yourPoolShare,
                                    baseAssetPooledByAccount: poolDetail.baseAssetPooledByAccount,
                                    targetAssetPooledByAccount: poolDetail.targetAssetPooledByAccount,
                                    baseAssetPooledTotal: poolDetail.baseAssetPooledTotal,
                                    targetAssetPooledTotal: poolDetail.targetAssetPooledTotal,
                                    totalIssuances: poolDetail.totalIssuances,
                                    baseAssetReserves: poolDetail.baseAssetReserves,
                                    targetAssetReserves: poolDetail.targetAssetReserves,
                                    accountPoolBalance: poolDetail.accountPoolBalance,
                                    farms: poolDetail.farms)
                }.sorted { $0.isFavorite && !$1.isFavorite }
                
                if self.currentOrder.isEmpty {
                    self.currentOrder = remotePoolInfo.map { $0.poolId }
                }

                let sortedPools = remotePoolInfo.sorted(by: self.orderSort)
                self.currentPools = sortedPools
                self.outputs.forEach {
                    ($0.target as? PoolsServiceOutput)?.loaded(pools: sortedPools)
                }
                
                let newOrUpdatedItems = remotePoolInfo.filter { !localPools.contains($0) }
                let removedItems = localPools.filter { !remotePoolInfo.contains($0) }
                
                return PoolsChanges(newOrUpdatedItems: newOrUpdatedItems, removedItems: removedItems)
            }

            let localSaveOperation = poolRepository.saveOperation({
                let changes = try processingOperation.extractNoCancellableResultData()
                return changes.newOrUpdatedItems
            }, {
                let changes = try processingOperation.extractNoCancellableResultData()
                return changes.removedItems.map(\.poolId)
            })
            
            processingOperation.addDependency(fetchOperation)
            fetchRemotePoolsOperation.allOperations.forEach { operation in
                processingOperation.addDependency(operation)
            }
            localSaveOperation.addDependency(processingOperation)

            operationManager.enqueue(
                operations: fetchRemotePoolsOperation.allOperations + [fetchOperation, processingOperation, localSaveOperation],
                in: .transient
            )
        }
    }
    
    func updatePools(_ pools: [PoolInfo]) {
        currentOrder = pools.sorted { $0.isFavorite && !$1.isFavorite }.map { $0.poolId }
        
        let pools = pools.map { $0.replacingVisible($0) }
        let localSaveOperation = poolRepository.replaceOperation({
            pools
        })

        currentPools = pools
        operationManager.enqueue(operations: [localSaveOperation], in: .transient)
    }
    
    func isPairEnabled(
        baseAssetId: String,
        targetAssetId: String,
        accountId: String,
        completion: @escaping (Bool) -> Void) {
            if currentPools.first(
                where: { $0.accountId == accountId &&
                    $0.baseAssetId == baseAssetId &&
                    $0.targetAssetId == targetAssetId }) != nil {
                completion(true)
                return
            }
            
            let dexId = polkaswapOperationFactory.dexId(for: baseAssetId)
            let operation = polkaswapOperationFactory.isPairEnabled(
                dexId: dexId,
                assetId: baseAssetId,
                tokenAddress: targetAssetId
            )
            operation.completionBlock = {
                DispatchQueue.main.async {
                    let isAvailable = ( try? operation.extractResultData() ) ?? false
                    completion(isAvailable)
                }
            }
            operationManager.enqueue(operations: [operation], in: .blockAfter)
    }
    
    func isPairPresentedInNetwork(
        baseAssetId: String,
        targetAssetId: String,
        accountId: String,
        completion: @escaping (Bool) -> Void) {
            if currentPools.first(
                where: { $0.accountId == accountId &&
                    $0.baseAssetId == baseAssetId &&
                    $0.targetAssetId == targetAssetId }) != nil {
                completion(true)
                return
            }
            
            let operationQueue = OperationQueue()
            operationQueue.qualityOfService = .utility
            
            guard let operation = try? polkaswapOperationFactory.poolReserves(baseAsset: baseAssetId, targetAsset: targetAssetId) else { return }
            operation.completionBlock = {
                DispatchQueue.main.async {
                    let reserves = try? operation.extractResultData()
                    completion(reserves?.underlyingValue != nil)
                }
            }

            operationManager.enqueue(operations: [operation], in: .blockAfter)
        }
}

extension AccountPoolsService {
    private func orderSort(_ asset0: PoolInfo, _ asset1: PoolInfo) -> Bool {
        if let index0 = currentOrder.firstIndex(where: { $0 == asset0.poolId }),
           let index1 = currentOrder.firstIndex(where: { $0 == asset1.poolId }) {
            return index0 < index1
        } else {
            return true
        }
    }
}
