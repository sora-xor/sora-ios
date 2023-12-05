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
import BigInt
import sorawallet
import SSFUtils

enum PoolError: Swift.Error {
    case noProperties
    case noReserves
}


extension WalletNetworkFacade {
    func getAccountPoolsDetails() throws -> CompoundOperationWrapper<[PoolDetails]> {
        let processingOperation: AwaitOperation<[PoolDetails]> = AwaitOperation { [weak self] in
            guard let weakSelf = self else { return [] }
            
            let accountPools = await weakSelf.loadAccountPools()
            var poolsDetails = try await weakSelf.loadPoolsDetails(accountPools: accountPools)
            poolsDetails = weakSelf.sort(poolDetails: poolsDetails)

            return poolsDetails
        }
        
        return CompoundOperationWrapper(targetOperation: processingOperation)
    }

    fileprivate func loadAccountPools() async -> [String: [String]] {
        let baseAssetIds = [WalletAssetId.xor.rawValue, WalletAssetId.xstusd.rawValue]
        
        async let pools = baseAssetIds.concurrentMap { baseAssetId in
            return await self.poolList(baseAssetId: baseAssetId)
        }
        
        let tempPools = try? await pools
        
        var result: [String: [String]] = [:]
        tempPools?.forEach { tempPool in
            result[tempPool.assetId] = tempPool.pools
        }
        
        return result
    }

    fileprivate func loadPoolsDetails(accountPools: [String: [String]]) async throws -> [PoolDetails] {
        return try await withCheckedThrowingContinuation({ continuetion in
            Task {
                async let poolsDetails = collectPools(accountPools: accountPools).concurrentMap { pool in
                    return try await self.getPoolDetails(baseAsset: pool.baseAsset, targetAsset: pool.targetAsset)
                }
                
                continuetion.resume(returning: try await poolsDetails)
            }
        })
    }
    
    fileprivate func collectPools(accountPools: [String: [String]]) -> [(baseAsset: String, targetAsset: String)] {
        var pools: [(baseAsset: String, targetAsset: String)] = []

        for pool in accountPools {
            for targetAsset in pool.value {
                pools.append((baseAsset: pool.key, targetAsset: targetAsset))
            }
        }

        return pools
    }

    fileprivate func sort(poolDetails: [PoolDetails]) -> [PoolDetails] {
        poolDetails.sorted(by: { poolDetails1, poolDetails2 in
            return poolDetails1.baseAsset < poolDetails2.baseAsset
        })
    }

    fileprivate func poolList(baseAssetId: String) async -> (assetId: String, pools: [String])? {
        let operationQueue = OperationQueue()
        let baseAssetIdData = (try? Data(hexStringSSF: baseAssetId)) ?? Data()
        guard let operation = try? polkaswapNetworkOperationFactory.accountPools(accountId: address.accountId!, baseAssetId: baseAssetIdData) else {
            return nil
        }
        operationQueue.addOperation(operation)
        
        return try? await withCheckedThrowingContinuation({ continuetion in
            operation.completionBlock = {
                let assetIds = (try? operation.extractResultData()?.underlyingValue?.assetIds) ?? []
                continuetion.resume(returning: (baseAssetId, assetIds))
            }
        })
    }
    
    func getPoolDetails(baseAsset: String, targetAsset: String) async throws -> PoolDetails {
        return try await withCheckedThrowingContinuation({ continuetion in

            let operationQueue = OperationQueue()
            operationQueue.qualityOfService = .utility
            
            // poolProperties
            guard let poolPropertiesOperation = try? self.polkaswapNetworkOperationFactory.poolProperties(baseAsset: baseAsset, targetAsset: targetAsset) else {
                continuetion.resume(throwing: PoolError.noProperties)
                return
            }

            // poolProviders
            guard let poolProvidersBalanceOperation = try? self.polkaswapNetworkOperationFactory.poolProvidersBalance() else {
                continuetion.resume(throwing: PoolError.noProperties)
                return
            }
            poolProvidersBalanceOperation.configurationBlock = {
                guard let accountId = self.address.accountId, let reservesAccountId = try? poolPropertiesOperation.extractResultData()?.underlyingValue?.reservesAccountId else {
                    return
                }
            
            let poolProvidersKey = (try? StorageKeyFactory().poolProvidersKey(reservesAccountId: reservesAccountId.value, accountId: accountId)) ?? Data()
                poolProvidersBalanceOperation.parameters = [ poolProvidersKey.toHex(includePrefix: true) ]
            }
            poolProvidersBalanceOperation.addDependency(poolPropertiesOperation)
                
            // totalIssuances
            guard let accountPoolTotalIssuancesOperation = try? self.polkaswapNetworkOperationFactory.poolTotalIssuances() else {
                continuetion.resume(throwing: PoolError.noProperties)
                return
            }
            
            accountPoolTotalIssuancesOperation.configurationBlock = {
                guard let reservesAccountId = try? poolPropertiesOperation.extractResultData()?.underlyingValue?.reservesAccountId else {
                    return
                }
                let accountPoolKey = (try? StorageKeyFactory().accountPoolTotalIssuancesKeyForId(reservesAccountId.value)) ?? Data()
                accountPoolTotalIssuancesOperation.parameters = [ accountPoolKey.toHex(includePrefix: true) ]
            }
            accountPoolTotalIssuancesOperation.addDependency(poolPropertiesOperation)
            
            // reserves
            guard let reservesOperation = try? self.polkaswapNetworkOperationFactory.poolReserves(baseAsset: baseAsset, targetAsset: targetAsset) else {
                continuetion.resume(throwing: PoolError.noProperties)
                return
            }
            
            // farms
            let farmsOperation: BaseOperation<[UserFarm]> = AwaitOperation { [weak self] in
                return await self?.demeterFarmingService.getUserFarmInfos(baseAssetId: baseAsset, targetAssetId: targetAsset) ?? []
            }
            
            let processingOperation: BaseOperation<Void> = ClosureOperation {
                
                guard let reserves = try? reservesOperation.extractResultData()?.underlyingValue else {
                    continuetion.resume(throwing: PoolError.noProperties)
                    return
                }
                
                let accountPoolBalance = (try? poolProvidersBalanceOperation.extractResultData()?.underlyingValue) ?? Balance(value: 0)
                let farms = (try? farmsOperation.extractResultData()) ?? []
                
                guard let totalIssuances = try? accountPoolTotalIssuancesOperation.extractResultData()?.underlyingValue else {
                    continuetion.resume(throwing: PoolError.noProperties)
                    return
                }
                
                let accountPoolBalanceDecimal = Decimal.fromSubstrateAmount(accountPoolBalance.value, precision: 18) ?? .zero
                let reservesDecimal = Decimal.fromSubstrateAmount(reserves.reserves.value, precision: 18) ?? .zero
                let totalIssuancesDecimal = Decimal.fromSubstrateAmount(totalIssuances.value, precision: 18) ?? .zero
                let targetAssetPooledTotalDecimal = Decimal.fromSubstrateAmount(reserves.fees.value, precision: 18) ?? .zero
                
                // XOR Pooled
                let yourPoolShare = totalIssuances.value > 0 ? accountPoolBalanceDecimal / totalIssuancesDecimal * 100 : .zero
                let xorPooled = totalIssuances.value > 0 ? reservesDecimal * accountPoolBalanceDecimal / totalIssuancesDecimal : .zero
                let targetPooled = totalIssuances.value > 0 ? targetAssetPooledTotalDecimal * accountPoolBalanceDecimal / totalIssuancesDecimal : .zero
                
                let poolDetails = PoolDetails(
                    baseAsset: baseAsset,
                    targetAsset: targetAsset,
                    yourPoolShare: yourPoolShare,
                    baseAssetPooledByAccount: xorPooled,
                    targetAssetPooledByAccount: targetPooled,
                    baseAssetPooledTotal: reservesDecimal,
                    targetAssetPooledTotal: targetAssetPooledTotalDecimal,
                    totalIssuances: Decimal.fromSubstrateAmount(totalIssuances.value, precision: 18) ?? 0.0,
                    baseAssetReserves: Decimal.fromSubstrateAmount(reserves.reserves.value, precision: 18) ?? 0.0,
                    targetAssetReserves: Decimal.fromSubstrateAmount(reserves.fees.value, precision: 18) ?? 0.0,
                    accountPoolBalance: accountPoolBalanceDecimal,
                    farms: farms)
                
                print("OLOLO getPoolDetails finished \(Date())")
                continuetion.resume(returning: poolDetails)
            }
            processingOperation.addDependency(poolPropertiesOperation)
            processingOperation.addDependency(poolProvidersBalanceOperation)
            processingOperation.addDependency(accountPoolTotalIssuancesOperation)
            processingOperation.addDependency(reservesOperation)
            processingOperation.addDependency(farmsOperation)
            
            operationQueue.addOperations([
                poolPropertiesOperation,
                reservesOperation,
                poolProvidersBalanceOperation,
                accountPoolTotalIssuancesOperation,
                farmsOperation,
                processingOperation
            ], waitUntilFinished: false)
        })
    }
}
