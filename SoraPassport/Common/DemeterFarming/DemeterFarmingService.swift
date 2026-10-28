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
import IrohaCrypto
import RobinHood
import SSFUtils

enum DemeterFarmingServiceError: Error {
    case unavailable
}

protocol DemeterFarmingServiceProtocol: AnyObject {
    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm]
    func loadUserFarmInfos(
        baseAssetId: String?,
        targetAssetId: String?,
        accountId: Data
    ) async throws -> [UserFarm]
    
    func getAllFarms() async throws -> [Farm]
    func getFarm(with id: String) -> Farm?
    
    func getFarmDetails(baseAssetId: String, poolAssetId: String, rewardAssetId: String) async throws -> [Farm]
    
    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void)
}

final class DemeterFarmingService {
    weak var poolsService: PoolsServiceInputProtocol?
    private var operationFactory: DemeterFarmingOperationFactory
    private let operationManager = OperationManager()
    private let fiatService: FiatService
    private let assetManager: AssetManagerProtocol
    private var farms: [Farm] = []
    private var farmsTask: Task<Void, Swift.Error>?
    
    init(operationFactory: DemeterFarmingOperationFactory,
         fiatService: FiatService,
         assetManager: AssetManagerProtocol) {
        self.operationFactory = operationFactory
        self.fiatService = fiatService
        self.assetManager = assetManager
    }
}

extension DemeterFarmingService: DemeterFarmingServiceProtocol {
    
    func getAllFarms() async throws -> [Farm] {
        if !farms.isEmpty {
            return farms
        }
        
        let poolsKeys = (try? await getPoolKeys()) ?? []
        
        async let farmList = poolsKeys.concurrentMap { [weak self] key -> [FarmedPool]? in
            let data = String(key.dropFirst(2))
            let assetId = data.components(withMaxLength: 64)
            guard assetId.count > 2 else {
                return nil
            }
            let pools = try? await self?.getPools(poolAssetId: "0x\(assetId[1])", rewardAssetId: "0x\(assetId[2])")
            return pools
        }
        
        let reducedFarms = (try? await farmList.reduce([], +)) ?? []
        
        let rewardTokenInfosKeys = (try? await getTokenInfosKeys()) ?? []
        
        async let rewardTokenInfos = rewardTokenInfosKeys.concurrentMap { [weak self] key in
            let data = String(key.dropFirst(2))
            let assetId = "0x\(data.components(withMaxLength: 64).last ?? "")"
            let pools = try? await self?.getRewardTokenInfos(with: assetId)
            return pools
        }
        
        let finalRewardTokenInfos = try? await rewardTokenInfos
        
        let fiatData = await fiatService.getFiat()
        
        async let farms = try? reducedFarms.concurrentMap { [weak self] pool in
            let baseAsset = self?.assetManager.assetInfo(for: pool.baseAssetId)
            let poolAsset = self?.assetManager.assetInfo(for: pool.poolAssetId)
            let rewardAsset = self?.assetManager.assetInfo(for: pool.rewardAssetId)
            
            let name = "\(baseAsset?.symbol ?? "")-\(poolAsset?.symbol ?? "")"
            let id = "\(baseAsset?.assetId ?? "")-\(poolAsset?.assetId ?? "")-\(rewardAsset?.assetId ?? "")"
            let rewardTokenInfo = finalRewardTokenInfos?.first { $0.assetId == pool.rewardAssetId }
            let emission = self?.calculateEmmision(farmedPool: pool, rewardTokenInfo: rewardTokenInfo) ?? Decimal(0)
            let poolInfo = await self?.poolsService?.getPool(by: pool.baseAssetId, targetAssetId: pool.poolAssetId)
            
            // A price that is not known leaves the value and the rate
            // unknown; they are not shown as "$0" and "0%".
            let knownPrice = fiatData.first { $0.id == pool.poolAssetId }?.priceUsd?.decimalValue
            let price = knownPrice ?? Decimal(0)
            let tvl = self?.calculateTVL(farmedPool: pool, poolInfo: poolInfo, price: price) ?? Decimal(0)
            
            let blockPerYear = Decimal(5256000)
            let knownRewardAssetPrice = fiatData.first { $0.id == pool.rewardAssetId }?.priceUsd?.decimalValue
            let rewardAssetPrice = knownRewardAssetPrice ?? Decimal(0)
            let apr = tvl.isZero ? 0 : emission * blockPerYear * rewardAssetPrice / tvl * 100
            let depositFee = pool.depositFee * 100
            
            return Farm(id: id,
                        name: name,
                        baseAsset: baseAsset,
                        poolAsset: poolAsset,
                        rewardAsset: rewardAsset,
                        tvl: tvl,
                        apr: apr / 100,
                        depositFee: depositFee,
                        tvlIsKnown: knownPrice != nil,
                        aprIsKnown: knownPrice != nil && knownRewardAssetPrice != nil)
        }
        
        let finalfarms = await farms ?? []
        self.farms = finalfarms
        return finalfarms
    }
    
    func getFarm(with id: String) -> Farm? {
        return farms.first(where: { $0.id == id })
    }
    
    func getFarmDetails(baseAssetId: String, poolAssetId: String, rewardAssetId: String) async throws -> [Farm] {
        async let farmedPools = (try? getPools(poolAssetId: poolAssetId, rewardAssetId: rewardAssetId)) ?? []
        
        async let rewardTokenInfos = try? getRewardTokenInfos(with: rewardAssetId)
        
        async let fiatData = self.fiatService.getFiat()
        
        let results = await (farmedPools: farmedPools.filter { $0.baseAssetId == baseAssetId },
                             rewardTokenInfos: rewardTokenInfos,
                             fiatData: fiatData)
        
        async let farms = try? results.farmedPools.concurrentMap { [weak self] pool in
            let baseAsset = self?.assetManager.assetInfo(for: pool.baseAssetId)
            let poolAsset = self?.assetManager.assetInfo(for: pool.poolAssetId)
            let rewardAsset = self?.assetManager.assetInfo(for: pool.rewardAssetId)
            
            let name = "\(baseAsset?.symbol ?? "")-\(poolAsset?.symbol ?? "")"
            let id = "\(baseAsset?.symbol ?? "")-\(poolAsset?.symbol ?? "")-\(rewardAsset?.symbol ?? "")"
            let rewardTokenInfo = results.rewardTokenInfos
            let emission = self?.calculateEmmision(farmedPool: pool, rewardTokenInfo: rewardTokenInfo) ?? Decimal(0)
            let poolInfo = await self?.poolsService?.getPool(by: pool.baseAssetId, targetAssetId: pool.poolAssetId)
            
            // A price that is not known leaves the value and the rate
            // unknown; they are not shown as "$0" and "0%".
            let knownPrice = results.fiatData.first { $0.id == pool.poolAssetId }?.priceUsd?.decimalValue
            let price = knownPrice ?? Decimal(0)
            let tvl = self?.calculateTVL(farmedPool: pool, poolInfo: poolInfo, price: price) ?? Decimal(0)
            
            let blockPerYear = Decimal(5256000)
            let knownRewardAssetPrice = results.fiatData.first { $0.id == pool.rewardAssetId }?.priceUsd?.decimalValue
            let rewardAssetPrice = knownRewardAssetPrice ?? Decimal(0)
            let apr = tvl.isZero ? 0 : emission * blockPerYear * rewardAssetPrice / tvl * 100
            let depositFee = pool.depositFee * 100
            
            return Farm(id: id,
                        name: name,
                        baseAsset: baseAsset,
                        poolAsset: poolAsset,
                        rewardAsset: rewardAsset,
                        tvl: tvl,
                        apr: apr / 100,
                        depositFee: depositFee,
                        tvlIsKnown: knownPrice != nil,
                        aprIsKnown: knownPrice != nil && knownRewardAssetPrice != nil)
        }

        return await farms ?? []
    }
    
    func getPoolKeys() async throws -> [String] {
        guard let keysOperation = try? operationFactory.poolsKeysPagedOperation() else { return [] }

        return await withCheckedContinuation { continuation in
            keysOperation.completionBlock = {
                guard let pools = try? keysOperation.extractResultData() else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: pools)
            }
            operationManager.enqueue(operations: [keysOperation], in: .transient)
        }
    }
    
    
    func getPools(poolAssetId: String, rewardAssetId: String) async throws -> [FarmedPool] {
        guard let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
              let poolsOperation = try? operationFactory.poolsOperation(poolAssetId: poolAssetId,
                                                                        rewardAssetId: rewardAssetId,
                                                                        runtimeOperation: runtimeService.fetchCoderFactoryOperation()) else {
            return []
        }

        return await withCheckedContinuation { continuation in
            poolsOperation.targetOperation.completionBlock = {
                do {
                    guard let allFarmInfos = try poolsOperation.targetOperation.extractResultData()?.filter({ $0.isFarm && !$0.isRemoved }) else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let farms = allFarmInfos.map { farm in
                        return FarmedPool(
                            baseAssetId: farm.baseAsset.value,
                            poolAssetId: poolAssetId,
                            rewardAssetId: rewardAssetId,
                            multiplier: ((Decimal(string: farm.multiplier) ?? .zero) as NSDecimalNumber).multiplying(byPowerOf10: -18).decimalValue,
                            depositFee: Decimal.fromSubstrateAmount(farm.depositFee, precision: 18) ?? .zero,
                            isCore: farm.isCore,
                            isFarm: farm.isFarm,
                            totalTokensInPool: Decimal.fromSubstrateAmount(farm.totalTokensInPool, precision: 18) ?? .zero,
                            rewards: Decimal.fromSubstrateAmount(farm.rewards, precision: 18) ?? .zero,
                            rewardsToBeDistributed: Decimal.fromSubstrateAmount(farm.rewardsToBeDistributed, precision: 18) ?? .zero,
                            isRemoved: farm.isRemoved
                        )
                    }
                    
                    continuation.resume(returning: farms)
                } catch {
                    continuation.resume(returning: [])
                }
            }
            operationManager.enqueue(operations: poolsOperation.allOperations, in: .transient)
        }
    }
    
    func getTokenInfosKeys() async throws -> [String] {
        guard let keysOperation = try? operationFactory.tokenInfosKeysPagedOperation() else { return [] }

        return await withCheckedContinuation { continuation in
            keysOperation.completionBlock = {
                guard let pools = try? keysOperation.extractResultData() else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: pools)
            }
            operationManager.enqueue(operations: [keysOperation], in: .transient)
        }
    }
    
    func getRewardTokenInfos(with assetId: String) async throws -> FarmedRewardTokenInfo? {
        guard let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
              let poolsOperation = try? operationFactory.tokenInfos(assetId: assetId,
                                                                    runtimeOperation: runtimeService.fetchCoderFactoryOperation()) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            poolsOperation.targetOperation.completionBlock = {
                do {
                    guard let assetInfo = try poolsOperation.targetOperation.extractResultData(), let assetInfo = assetInfo else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let rewardAssetInfo = FarmedRewardTokenInfo(
                        assetId: assetId,
                        farmsTotalMultiplier: ((Decimal(string: assetInfo.farmsTotalMultiplier) ?? .zero) as NSDecimalNumber).multiplying(byPowerOf10: -18).decimalValue,
                        stakingTotalMultiplier: ((Decimal(string: assetInfo.stakingTotalMultiplier) ?? .zero) as NSDecimalNumber).multiplying(byPowerOf10: -18).decimalValue,
                        tokenPerBlock: Decimal.fromSubstrateAmount(assetInfo.tokenPerBlock, precision: 18) ?? .zero,
                        farmsAllocation: Decimal.fromSubstrateAmount(assetInfo.farmsAllocation, precision: 18) ?? .zero,
                        stakingAllocation: Decimal.fromSubstrateAmount(assetInfo.stakingAllocation, precision: 18) ?? .zero
                    )

                    continuation.resume(returning: rewardAssetInfo)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
            operationManager.enqueue(operations: poolsOperation.allOperations, in: .transient)
        }
    }

    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm] {
        guard let account = SelectedWalletSettings.shared.currentAccount,
              let accountId = try? SS58AddressFactory().accountId(
                fromAddress: account.address,
                type: account.networkType
              ) else {
            return []
        }
        return (try? await loadUserFarmInfos(
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId,
            accountId: accountId
        )) ?? []
    }

    func loadUserFarmInfos(
        baseAssetId: String?,
        targetAssetId: String?,
        accountId: Data
    ) async throws -> [UserFarm] {
        guard let baseAssetId, let targetAssetId,
              !accountId.isEmpty,
              let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
              let farmedPoolsOperation = try? operationFactory.userInfo(
                accountId: accountId,
                runtimeOperation: runtimeService.fetchCoderFactoryOperation()
              ) else {
            throw DemeterFarmingServiceError.unavailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            farmedPoolsOperation.targetOperation.completionBlock = {
                do {
                    let userFarms = try farmedPoolsOperation.targetOperation
                        .extractResultData(
                            throwing: DemeterFarmingServiceError.unavailable
                        )
                    let filtredUserFarms = userFarms.filter {
                        baseAssetId == $0.baseAsset.value
                            && targetAssetId == $0.poolAsset.value
                            && $0.isFarm
                    }
                    let farms = try filtredUserFarms.map {
                        guard let pooledTokens = Decimal.fromSubstrateAmount(
                            $0.pooledTokens,
                            precision: 18
                        ), let rewards = Decimal.fromSubstrateAmount(
                            $0.rewards,
                            precision: 18
                        ) else {
                            throw DemeterFarmingServiceError.unavailable
                        }

                        return UserFarm(
                            id: "\($0.baseAsset.value)-\($0.poolAsset.value)-\($0.rewardAsset.value)",
                            baseAssetId: $0.baseAsset.value,
                            poolAssetId: $0.poolAsset.value,
                            rewardAssetId: $0.rewardAsset.value,
                            isFarm: $0.isFarm,
                            pooledTokens: pooledTokens,
                            rewards: rewards
                        )
                    }
                    continuation.resume(returning: farms)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            operationManager.enqueue(operations: farmedPoolsOperation.allOperations, in: .transient)
        }
    }

    func getSingleSidedXorFarmedPools(completion: @escaping ([UserFarmInfo]) -> Void) {
        guard let account = SelectedWalletSettings.shared.currentAccount,
              let accountId = try? SS58AddressFactory().accountId(fromAddress: account.address, type: account.networkType),
              let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
              let farmedPoolsOperation = try? operationFactory.userInfo(
                accountId: accountId,
                runtimeOperation: runtimeService.fetchCoderFactoryOperation()
              )
        else {
            completion([])
            return
        }

        farmedPoolsOperation.targetOperation.completionBlock = {
            guard let pools = try? farmedPoolsOperation.targetOperation.extractResultData() else {
                completion([])
                return
            }
            let xorId = WalletAssetId.xor.rawValue
            let filtredPools = pools.filter { $0.poolAsset.value == xorId && !($0.isFarm) }
            completion(filtredPools)
        }

        operationManager.enqueue(operations: farmedPoolsOperation.allOperations, in: .transient)
    }
    
    private func calculateEmmision(farmedPool: FarmedPool, rewardTokenInfo: FarmedRewardTokenInfo?) -> Decimal {
        guard let rewardTokenInfo else { return .zero }
        
        let tokenMultiplier = farmedPool.isFarm ? rewardTokenInfo.farmsTotalMultiplier : rewardTokenInfo.stakingTotalMultiplier

        if tokenMultiplier.isZero {
            return .zero
        }
        
        let multiplier = farmedPool.multiplier / tokenMultiplier
        
        let allocation = farmedPool.isFarm ? rewardTokenInfo.farmsAllocation : rewardTokenInfo.stakingAllocation
        
        return allocation * rewardTokenInfo.tokenPerBlock * multiplier
    }
    
    private func calculateTVL(farmedPool: FarmedPool, poolInfo: PoolInfo?, price: Decimal) -> Decimal {
        guard let poolInfo else { return .zero }

        if farmedPool.isFarm {
            let kf = (poolInfo.targetAssetReserves ?? Decimal(0)) / (poolInfo.totalIssuances ?? Decimal(0))
            return kf * farmedPool.totalTokensInPool * 2 * price
        }

        return farmedPool.totalTokensInPool * price
    }
}
