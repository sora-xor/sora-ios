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

import SSFUtils
import RobinHood
import sorawallet
import IrohaCrypto

protocol ExplorePoolsServiceInputProtocol: AnyObject {
    func getPools(with fiatData: [FiatData]) async throws -> [ExplorePool]
}

protocol ExplorePoolsServiceOutput: AnyObject {
}

struct ExplorePool {
    let id: String
    let baseAssetId: String
    let targetAssetId: String
    var tvl: Decimal
    var apy: Decimal?
}

final class ExplorePoolsService {
    
    private let operationManager: OperationManagerProtocol = OperationManager()
    private weak var polkaswapOperationFactory: PolkaswapNetworkOperationFactoryProtocol?
    private weak var fiatService: FiatServiceProtocol?
    private var networkFacade: WalletNetworkOperationFactoryProtocol?
    private var pools: [ExplorePool] = []
    private let assetInfos: [AssetInfo]
    private var task: Task<Void, Swift.Error>?
    
    init(
        assetInfos: [AssetInfo],
        fiatService: FiatServiceProtocol?,
        polkaswapOperationFactory: PolkaswapNetworkOperationFactoryProtocol?,
        networkFacade: WalletNetworkOperationFactoryProtocol?
    ) {
        self.assetInfos = assetInfos
        self.fiatService = fiatService
        self.polkaswapOperationFactory = polkaswapOperationFactory
        self.networkFacade = networkFacade
    }
}

extension ExplorePoolsService: ExplorePoolsServiceInputProtocol {
    
    func getPools(with fiatData: [FiatData]) async throws -> [ExplorePool] {
        return await withCheckedContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(returning: [])
                return
            }

            self.task?.cancel()
            self.task = Task {
                if !self.pools.isEmpty {
                    continuation.resume(returning: self.pools)
                    return
                }
                
                let baseAssetIds = [WalletAssetId.xor.rawValue, WalletAssetId.xstusd.rawValue]
                let targetAssetIds: [String] = self.assetInfos.filter { !baseAssetIds.contains($0.assetId) }.map { $0.assetId }

                async let explorePools = self.collectPools(baseAssetIds: baseAssetIds, targetAssetIds: targetAssetIds).concurrentMap({ poolTuple in
                    return await self.createExplorePool(poolTuple: poolTuple, fiatData: fiatData)
                }).sorted(by: { $0.tvl > $1.tvl })
                
                let pools = (try? await explorePools) ?? []
                self.pools = pools
                continuation.resume(returning: pools)
            }
        }
    }
    
    private func collectPools(baseAssetIds: [String], targetAssetIds: [String]) -> [(baseAssetId: String, targetAssetId: String)] {
        var poolTuples: [(baseAssetId: String, targetAssetId: String)] = []
        
        for baseAssetId in baseAssetIds {
            for targetAssetId in targetAssetIds {
                poolTuples.append((baseAssetId, targetAssetId))
            }
        }
        return poolTuples
    }
    
    private func createExplorePool(poolTuple: (baseAssetId: String, targetAssetId: String), fiatData: [FiatData]) async -> ExplorePool? {
        return await withCheckedContinuation { continuation in
            let operation = try? polkaswapOperationFactory?.poolReserves(baseAsset: poolTuple.baseAssetId, targetAsset: poolTuple.targetAssetId)
            operation?.completionBlock = { [weak self] in
                
                guard let reserves = try? operation?.extractResultData()?.underlyingValue?.reserves else { 
                    continuation.resume(returning: nil)
                    return
                }
                let reservesDecimal = Decimal.fromSubstrateAmount(reserves.value, precision: 18) ?? .zero
                
                let priceUsd = fiatData.first(where: { $0.id == poolTuple.baseAssetId })?.priceUsd?.decimalValue ?? .zero
                
                let accountId = (self?.networkFacade as? WalletNetworkFacade)?.accountSettings.accountId ?? ""
                
                let idData = NSMutableData()
                idData.append(Data(poolTuple.baseAssetId.utf8))
                idData.append(Data(poolTuple.targetAssetId.utf8))
                idData.append(Data(accountId.utf8))
                let poolId = String(idData.hashValue)
                
                continuation.resume(returning: ExplorePool(id: poolId,
                                                           baseAssetId: poolTuple.baseAssetId,
                                                           targetAssetId: poolTuple.targetAssetId,
                                                           tvl: priceUsd * reservesDecimal * 2))
            }
            if let operation {
                operationManager.enqueue(operations: [operation], in: .transient)
            }
        }
    }
}
