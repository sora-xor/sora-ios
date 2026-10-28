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
import SSFStorageQueryKitFixed

protocol PoolsServiceInputProtocol: AnyObject {
    func loadAccountPools()
    func getAccountPools() -> [PoolInfo]
    func updatePools(_ pools: [PoolInfo])
    func getPool(by id: String) -> PoolInfo?
    func getPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo?
    func loadPool(by baseAssetId: String, targetAssetId: String) async -> PoolInfo?
    func loadPairState(baseAssetId: String, targetAssetId: String) async throws -> PoolNetworkState
    func loadPools(currentAsset: AssetInfo) -> [PoolInfo]
    func loadTargetPools(for baseAssetId: String) -> [PoolInfo]
    func appendDelegate(delegate: PoolsServiceOutput)
}

struct PoolNetworkState: Equatable, Sendable {
    let isPresented: Bool
    let isEnabled: Bool

    var liquidityAction: LiquidityPairAction {
        switch (isPresented, isEnabled) {
        case (false, false):
            return .registerInitializeAndDeposit
        case (false, true):
            return .initializeAndDeposit
        case (true, true):
            return .deposit
        case (true, false):
            return .reject
        }
    }
}

enum LiquidityPairAction: Equatable, Sendable {
    case registerInitializeAndDeposit
    case initializeAndDeposit
    case deposit
    case reject
}

protocol PoolsServiceOutput: AnyObject {
    func loaded(pools: [PoolInfo])
}

protocol AccountPoolDetailsProviding: AnyObject {
    var address: String { get }
    var accountSettings: WalletAccountSettingsProtocol { get }
    func getAccountPoolsDetails() throws -> CompoundOperationWrapper<[PoolDetails]>
    func getPoolDetails(baseAsset: String, targetAsset: String) async throws -> PoolDetails
}

extension WalletNetworkFacade: AccountPoolDetailsProviding {}

final class AccountPoolsService {
    
    struct PoolsChanges {
        let newOrUpdatedItems: [PoolInfo]
        let removedItems: [PoolInfo]
        var replacedIds: [String: String] = [:]
    }

    var outputs: [WeakWrapper] = []
    var networkFacade: WalletNetworkOperationFactoryProtocol?
    var polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?
    let operationManager: OperationManagerProtocol
    
    var subscriptionIds: [UInt16] = []
    var subscriptionUpdates: [String: String] = [:]
    private let config: ApplicationConfigProtocol
    private let poolRepository: AnyDataProviderRepository<PoolInfo>
    private var currentPools: [PoolInfo] = []
    private var polkaswapOperationFactory: PolkaswapNetworkOperationFactoryProtocol
    private var loadOperations: [Operation] = []
    private var loadGeneration = UUID()
    private var subscriptionGeneration = UUID()
    private var subscribedKeys = Set<String>()
    private let detailsProvider: AccountPoolDetailsProviding?
    private let runtimeService: RuntimeCodingServiceProtocol?
    private let preferences: UserDefaults
    private let prefetchDex: () -> Void
    private let dexIdProvider: (String) async -> UInt32?
    
    var currentOrder: [String] {
        get {
            return preferences.array(forKey: "poolsOrder") as? [String] ?? []
        }
        set {
            preferences.set(newValue, forKey: "poolsOrder")
        }
    }
    
    init(
        operationManager: OperationManagerProtocol,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
        config: ApplicationConfigProtocol,
        poolRepository: AnyDataProviderRepository<PoolInfo>? = nil,
        detailsProvider: AccountPoolDetailsProviding? = nil,
        runtimeService: RuntimeCodingServiceProtocol? = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
        polkaswapOperationFactory: PolkaswapNetworkOperationFactoryProtocol? = nil,
        preferences: UserDefaults = .standard,
        prefetchDex: @escaping () -> Void = { DexInfoService.shared.prefetch() },
        dexIdProvider: @escaping (String) async -> UInt32? = { await DexInfoService.shared.dexId(forBaseAssetId: $0) },
        startAutomatically: Bool = true
    ) {
        self.operationManager = operationManager
        self.networkFacade = networkFacade
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.config = config
        
        self.detailsProvider = detailsProvider ?? (networkFacade as? AccountPoolDetailsProviding)
        self.runtimeService = runtimeService
        self.preferences = preferences
        self.prefetchDex = prefetchDex
        self.dexIdProvider = dexIdProvider
        self.polkaswapOperationFactory = polkaswapOperationFactory ?? polkaswapNetworkFacade ?? PolkaswapNetworkOperationFactory(engine: ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash())!)
        
        self.poolRepository = poolRepository ?? AnyDataProviderRepository(PoolRepositoryFactory().createRepository())
        
        if startAutomatically { setup() }
    }
    
    deinit {
        loadOperations.forEach { $0.cancel() }
        unsubscribePoolsReserves()
    }

    func setup() {
        // Read the chain's DEX ids early, so liquidity screens for KUSD or VXOR
        // based pools find them without waiting.
        prefetchDex()
        unsubscribePoolsReserves()
        subscribeAccountPool(baseAssetId: WalletAssetId.xor.rawValue)
        subscribeAccountPool(baseAssetId: WalletAssetId.xstusd.rawValue)
        loadAccountPools()
    }
    
    func subscribeAccountPool(baseAssetId: String) {
        let identity = "account:" + baseAssetId
        guard let engine = polkaswapNetworkFacade?.engine,
              !subscribedKeys.contains(identity) else { return }
        let generation = subscriptionGeneration
        do {
            guard let accountId = detailsProvider?.address.accountId,
                  let baseAssetIdData = try? Data(hexStringSSF: baseAssetId) else { return }
            let storageKey = try StorageKeyFactory()
                .accountPoolsKeyForId(accountId, baseAssetId: baseAssetIdData)
                .toHex(includePrefix: true)
            
            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in
                Task { @MainActor [weak self] in
                    guard let self, self.subscriptionGeneration == generation,
                          let assetIds = try? await self.decodeCodes(with: update),
                          self.subscriptionGeneration == generation else { return }
                    assetIds.forEach { targetAssetId in
                        self.subscribePoolReserves(baseAsset: baseAssetId, targetAsset: targetAssetId)
                    }
                }
            }
            
            let subscriptionId = try engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: { _, _ in })
            subscriptionIds.append(subscriptionId)
            subscribedKeys.insert(identity)
        } catch {
            print("Account-pools storage subscription failed")
        }
    }
    
    private func decodeCodes(with update: JSONRPCSubscriptionUpdate<StorageUpdate>) async throws -> [String] {
        guard let runtimeService else { throw BaseOperationError.unexpectedDependentResult }
        let fetchCoderFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        
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
                    print("Account-pools storage decoding failed")
                    continuetion.resume(throwing: error)
                }
            }
            operationManager.enqueue(operations: [fetchCoderFactoryOperation, decodingOperation], in: .transient)
        }
    }
    
    func subscribePoolReserves(baseAsset: String, targetAsset: String) {
        let identity = "reserves:" + baseAsset + ":" + targetAsset
        guard let engine = polkaswapNetworkFacade?.engine,
              !subscribedKeys.contains(identity) else { return }
        let generation = subscriptionGeneration
        do {
            let storageKey = try StorageKeyFactory()
                .poolReservesKey(baseAssetId: Data.sora(hex: baseAsset), targetAssetId: Data.sora(hex: targetAsset))
                .toHex(includePrefix: true)
            
            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.subscriptionGeneration == generation else { return }
                    let blockHash = update.params.result.blockHash
                    guard let previous = self.subscriptionUpdates[identity] else {
                        self.subscriptionUpdates[identity] = blockHash
                        return
                    }
                    guard previous != blockHash else { return }
                    self.subscriptionUpdates[identity] = blockHash
                    self.loadAccountPools()
                }
            }

            let subscriptionId = try engine.subscribe(RPCMethod.storageSubscribe,
                                                                              params: [[storageKey]],
                                                                              updateClosure: updateClosure,
                                                                              failureClosure: { _, _ in })
            subscriptionIds.append(subscriptionId)
            subscribedKeys.insert(identity)
        } catch {
            print("Account-pools storage subscription failed")
        }
    }
    
    func unsubscribePoolsReserves() {
        subscriptionGeneration = UUID()
        subscribedKeys.removeAll()
        subscriptionIds.forEach({
            polkaswapNetworkFacade?.engine.cancelForIdentifier($0)
        })
        subscriptionIds = []
        subscriptionUpdates = [:]
    }
}

extension AccountPoolsService: PoolsServiceInputProtocol {
    func appendDelegate(delegate: PoolsServiceOutput) {
        outputs.removeAll { $0.target == nil }
        guard !outputs.contains(where: { $0.target === delegate }) else { return }
        outputs.append(WeakWrapper(target: delegate))
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
        guard let poolDetails = try? await detailsProvider?.getPoolDetails(
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

    func loadPairState(baseAssetId: String, targetAssetId: String) async throws -> PoolNetworkState {
        async let isPresented = loadPairPresence(
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId
        )
        async let isEnabled = loadPairAvailability(
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId
        )

        let state = try await (isPresented, isEnabled)
        return PoolNetworkState(isPresented: state.0, isEnabled: state.1)
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
        Task { @MainActor [weak self] in
            guard let self else { return }
            let generation = UUID()
            loadGeneration = generation
            loadOperations.forEach { $0.cancel() }
            guard let fetchRemotePoolsOperation = try? detailsProvider?.getAccountPoolsDetails() else { return }
            let fetchOperation = poolRepository.fetchAllOperation(with: RepositoryFetchOptions())
            
            let processingOperation: BaseOperation<PoolsChanges> = ClosureOperation { [weak self] in
                guard let self = self else { return PoolsChanges(newOrUpdatedItems: [], removedItems: []) }
                let localPools = try fetchOperation.extractNoCancellableResultData()
                let remotePoolDetails = try fetchRemotePoolsOperation.targetOperation.extractNoCancellableResultData()
                let accountId = self.detailsProvider?.accountSettings.accountId ?? ""

                var replacedIds = [String: String]()
                let remotePoolInfo = try remotePoolDetails.map { poolDetail -> PoolInfo in
                    let identity = [accountId, poolDetail.baseAsset, poolDetail.targetAsset].joined(separator: "\0")
                    let poolId = try Data(identity.utf8).blake2b32().toHex()
                    let previous = localPools.first {
                        $0.accountId == accountId &&
                        $0.baseAssetId == poolDetail.baseAsset &&
                        $0.targetAssetId == poolDetail.targetAsset
                    }
                    if let previous, previous.poolId != poolId { replacedIds[previous.poolId] = poolId }
                    
                    return PoolInfo(baseAssetId: poolDetail.baseAsset,
                                    targetAssetId: poolDetail.targetAsset,
                                    poolId: poolId,
                                    isFavorite: previous?.isFavorite ?? true,
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
                
                let newOrUpdatedItems = remotePoolInfo
                let removedItems = localPools.filter { !remotePoolInfo.contains($0) }
                
                return PoolsChanges(newOrUpdatedItems: newOrUpdatedItems, removedItems: removedItems, replacedIds: replacedIds)
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
            localSaveOperation.completionBlock = { [weak self, weak localSaveOperation] in
                guard case .success = localSaveOperation?.result,
                      let changes = try? processingOperation.extractNoCancellableResultData() else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.loadGeneration == generation else { return }
                    let remotePools = changes.newOrUpdatedItems
                    self.currentOrder = self.currentOrder.map { changes.replacedIds[$0] ?? $0 }
                    if self.currentOrder.isEmpty { self.currentOrder = remotePools.map(\.poolId) }
                    let sortedPools = remotePools.sorted(by: self.orderSort)
                    self.currentPools = sortedPools
                    self.outputs.forEach { ($0.target as? PoolsServiceOutput)?.loaded(pools: sortedPools) }
                }
            }

            loadOperations = fetchRemotePoolsOperation.allOperations + [fetchOperation, processingOperation, localSaveOperation]
            operationManager.enqueue(
                operations: loadOperations,
                in: .transient
            )
        }
    }
    
    func updatePools(_ pools: [PoolInfo]) {
        loadGeneration = UUID()
        loadOperations.forEach { $0.cancel() }
        currentOrder = pools.sorted { $0.isFavorite && !$1.isFavorite }.map { $0.poolId }
        
        let pools = pools.map { $0.replacingVisible($0) }
        let localSaveOperation = poolRepository.replaceOperation({
            pools
        })

        currentPools = pools
        operationManager.enqueue(operations: [localSaveOperation], in: .transient)
    }
}

extension AccountPoolsService {
    private func loadPairPresence(baseAssetId: String, targetAssetId: String) async throws -> Bool {
        let operation = try polkaswapOperationFactory.poolReserves(
            baseAsset: baseAssetId,
            targetAsset: targetAssetId
        )

        return try await withCheckedThrowingContinuation { continuation in
            operation.completionBlock = {
                do {
                    let reserves = try operation.extractResultData()
                    continuation.resume(returning: reserves?.underlyingValue != nil)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            operationManager.enqueue(operations: [operation], in: .transient)
        }
    }

    private func loadPairAvailability(baseAssetId: String, targetAssetId: String) async throws -> Bool {
        // A pair can only be enabled on the DEX whose base asset this is.
        guard let dexId = await dexIdProvider(baseAssetId) else {
            return false
        }
        let operation = polkaswapOperationFactory.isPairEnabled(
            dexId: dexId,
            assetId: baseAssetId,
            tokenAddress: targetAssetId
        )

        return try await withCheckedThrowingContinuation { continuation in
            operation.completionBlock = {
                do {
                    continuation.resume(returning: try operation.extractResultData(
                        throwing: BaseOperationError.parentOperationCancelled
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            operationManager.enqueue(operations: [operation], in: .transient)
        }
    }

    private func orderSort(_ asset0: PoolInfo, _ asset1: PoolInfo) -> Bool {
        let index0 = currentOrder.firstIndex(of: asset0.poolId) ?? Int.max
        let index1 = currentOrder.firstIndex(of: asset1.poolId) ?? Int.max
        if index0 != index1 { return index0 < index1 }
        return asset0.poolId < asset1.poolId
    }
}
