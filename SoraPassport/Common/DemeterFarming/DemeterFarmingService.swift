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
import IrohaCrypto
import RobinHood
import SSFUtils

protocol DemeterFarmingServiceProtocol: AnyObject {
    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?, completion: @escaping ([UserFarm]) -> Void)
    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm]
    
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
        return await withCheckedContinuation { continuation in
            farmsTask?.cancel()
            farmsTask = Task {
                if !farms.isEmpty {
                    continuation.resume(returning: farms)
                    return
                }

                let poolsKeys = (try? await getPoolKeys()) ?? []
                
                async let farmList = poolsKeys.concurrentMap { [weak self] key in
                    let data = String(key.dropFirst(2))
                    let assetId = data.components(withMaxLength: 64)
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
                    let id = "\(baseAsset?.symbol ?? "")-\(poolAsset?.symbol ?? "")-\(rewardAsset?.symbol ?? "")"
                    let rewardTokenInfo = finalRewardTokenInfos?.first { $0.assetId == pool.rewardAssetId }
                    let emission = self?.calculateEmmision(farmedPool: pool, rewardTokenInfo: rewardTokenInfo) ?? Decimal(0)
                    let poolInfo = await self?.poolsService?.getPool(by: pool.baseAssetId, targetAssetId: pool.poolAssetId)

                    let price = fiatData.first { $0.id == pool.poolAssetId }?.priceUsd?.decimalValue ?? Decimal(0)
                    let tvl = self?.calculateTVL(farmedPool: pool, poolInfo: poolInfo, price: price) ?? Decimal(0)
                    
                    let blockPerYear = Decimal(5256000)
                    let rewardAssetPrice = fiatData.first { $0.id == pool.rewardAssetId }?.priceUsd?.decimalValue ?? Decimal(0)
                    let apr = tvl.isZero ? 0 : emission * blockPerYear * rewardAssetPrice / tvl * 100
                    let depositFee = pool.depositFee * 100

                    return Farm(id: id,
                                name: name,
                                baseAsset: baseAsset,
                                poolAsset: poolAsset,
                                rewardAsset: rewardAsset,
                                tvl: tvl,
                                apr: apr / 100,
                                depositFee: depositFee)
                }
                
                let finalfarms = await farms ?? []
                self.farms = finalfarms
                continuation.resume(returning: finalfarms)
            }
        }
    }
    
    func getFarm(with id: String) -> Farm? {
        guard let farm = farms.first(where: { $0.id == id })  else { return nil }
        return farm
    }
    
    func getFarmDetails(baseAssetId: String, poolAssetId: String, rewardAssetId: String) async throws -> [Farm] {
        return await withCheckedContinuation { continuation in
            farmsTask?.cancel()
            farmsTask = Task {
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

                    let price = results.fiatData.first { $0.id == pool.poolAssetId }?.priceUsd?.decimalValue ?? Decimal(0)
                    let tvl = self?.calculateTVL(farmedPool: pool, poolInfo: poolInfo, price: price) ?? Decimal(0)
                    
                    let blockPerYear = Decimal(5256000)
                    let rewardAssetPrice = results.fiatData.first { $0.id == pool.rewardAssetId }?.priceUsd?.decimalValue ?? Decimal(0)
                    let apr = tvl.isZero ? 0 : emission * blockPerYear * rewardAssetPrice / tvl * 100
                    let depositFee = pool.depositFee * 100

                    return Farm(id: id,
                                name: name,
                                baseAsset: baseAsset,
                                poolAsset: poolAsset,
                                rewardAsset: rewardAsset,
                                tvl: tvl,
                                apr: apr / 100,
                                depositFee: depositFee)
                }
                
                let finalfarms = await farms ?? []
                continuation.resume(returning: finalfarms)
            }
        }
    }
    
    func getPoolKeys() async throws -> [String] {
        guard let keysOperation = try? operationFactory.poolsKeysPagedOperation() else { return [] }
        operationManager.enqueue(operations: [keysOperation], in: .transient)
        
        return await withCheckedContinuation { continuation in
            keysOperation.completionBlock = {
                guard let pools = try? keysOperation.extractResultData() else { return }
                continuation.resume(returning: pools)
            }
        }
    }
    
    
    func getPools(poolAssetId: String, rewardAssetId: String) async throws -> [FarmedPool] {
        guard let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
              let poolsOperation = try? operationFactory.poolsOperation(poolAssetId: poolAssetId,
                                                                        rewardAssetId: rewardAssetId,
                                                                        runtimeOperation: runtimeService.fetchCoderFactoryOperation()) else {
            return []
        }

        operationManager.enqueue(operations: poolsOperation.allOperations, in: .transient)
        
        return await withCheckedContinuation { continuation in
            poolsOperation.targetOperation.completionBlock = {
                do {
                    guard let allFarmInfos = try poolsOperation.targetOperation.extractResultData()?.filter({ $0.isFarm && !$0.isRemoved }) else {
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
        }
    }
    
    func getTokenInfosKeys() async throws -> [String] {
        guard let keysOperation = try? operationFactory.tokenInfosKeysPagedOperation() else { return [] }
        operationManager.enqueue(operations: [keysOperation], in: .transient)
        
        return await withCheckedContinuation { continuation in
            keysOperation.completionBlock = {
                guard let pools = try? keysOperation.extractResultData() else { return }
                continuation.resume(returning: pools)
            }
        }
    }
    
    func getRewardTokenInfos(with assetId: String) async throws -> FarmedRewardTokenInfo? {
        guard let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
              let poolsOperation = try? operationFactory.tokenInfos(assetId: assetId,
                                                                    runtimeOperation: runtimeService.fetchCoderFactoryOperation()) else {
            return nil
        }

        operationManager.enqueue(operations: poolsOperation.allOperations, in: .transient)
        
        return await withCheckedContinuation { continuation in
            poolsOperation.targetOperation.completionBlock = {
                do {
                    guard let assetInfo = try poolsOperation.targetOperation.extractResultData(), let assetInfo = assetInfo else { return }
                    
                    let rewardAssetInfo = FarmedRewardTokenInfo(
                        assetId: assetId,
                        farmsTotalMultiplier: ((Decimal(string: assetInfo.farmsTotalMultiplier) ?? .zero) as NSDecimalNumber).multiplying(byPowerOf10: -18).decimalValue,
                        stakingTotalMultiplier: ((Decimal(string: assetInfo.stakingTotalMultiplier) ?? .zero) as NSDecimalNumber).multiplying(byPowerOf10: -18).decimalValue,
                        tokenPerBlock: Decimal.fromSubstrateAmount(assetInfo.tokenPerBlock, precision: 18) ?? .zero,
                        farmsAllocation: Decimal.fromSubstrateAmount(assetInfo.farmsAllocation, precision: 18) ?? .zero,
                        stakingAllocation: Decimal.fromSubstrateAmount(assetInfo.stakingAllocation, precision: 18) ?? .zero
                    )

                    continuation.resume(returning: rewardAssetInfo)
                } catch { }
            }
        }
    }
    

    @available(*, renamed: "getFarmedPools(baseAssetId:targetAssetId:)")
    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?, completion: @escaping ([UserFarm]) -> Void) {
        Task {
            let result = await getUserFarmInfos(baseAssetId: baseAssetId, targetAssetId: targetAssetId)
            completion(result)
        }
    }
    
    
    func getUserFarmInfos(baseAssetId: String?, targetAssetId: String?) async -> [UserFarm] {
        guard let baseAssetId, let targetAssetId,
              let account = SelectedWalletSettings.shared.currentAccount,
              let accountId = try? SS58AddressFactory().accountId(fromAddress: account.address, type: account.networkType),
              let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: Chain.sora.genesisHash()),
              let farmedPoolsOperation = try? operationFactory.userInfo(
                accountId: accountId,
                runtimeOperation: runtimeService.fetchCoderFactoryOperation()
              ) else {
            return []
        }
        operationManager.enqueue(operations: farmedPoolsOperation.allOperations, in: .transient)
        
        return await withCheckedContinuation { continuation in
            farmedPoolsOperation.targetOperation.completionBlock = {
                guard let userFarms = try? farmedPoolsOperation.targetOperation.extractResultData() else { return }
                let filtredUserFarms = userFarms.filter { baseAssetId == $0.baseAsset.value && targetAssetId == $0.poolAsset.value && $0.isFarm }
                let farms = filtredUserFarms.map {
                    UserFarm(
                        baseAssetId: $0.baseAsset.value,
                        poolAssetId: $0.poolAsset.value,
                        rewardAssetId: $0.rewardAsset.value,
                        isFarm: $0.isFarm,
                        pooledTokens: Decimal.fromSubstrateAmount($0.pooledTokens, precision: 18) ?? .zero,
                        rewards: Decimal.fromSubstrateAmount($0.pooledTokens, precision: 18) ?? .zero
                    )
                }
                continuation.resume(returning: farms)
            }
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
            return
        }

        farmedPoolsOperation.targetOperation.completionBlock = {
            guard let pools = try? farmedPoolsOperation.targetOperation.extractResultData() else { return }
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
