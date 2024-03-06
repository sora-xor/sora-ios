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

import CommonWallet
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
    private let remotePolkaswapService: RemotePolkaswapPoolsService
    private var task: Task<Void, Swift.Error>?
    
    init(
        assetInfos: [AssetInfo],
        fiatService: FiatServiceProtocol?,
        polkaswapOperationFactory: PolkaswapNetworkOperationFactoryProtocol?,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        remotePolkaswapService: RemotePolkaswapPoolsService
    ) {
        self.assetInfos = assetInfos
        self.fiatService = fiatService
        self.polkaswapOperationFactory = polkaswapOperationFactory
        self.networkFacade = networkFacade
        self.remotePolkaswapService = remotePolkaswapService
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
            self.task = Task { [weak self] in
                guard let self else { return }
                
                if !self.pools.isEmpty {
                    continuation.resume(returning: self.pools)
                    return
                }
                
                let baseAssetIds = try await self.remotePolkaswapService.getBaseAssetIds()
                print("OLOLO liquidityPairs \(baseAssetIds)")
                
                async let pairsReservesIds = baseAssetIds.concurrentMap { baseAsset in
                    return try await self.remotePolkaswapService.getPoolReservesId(baseAssetId: baseAsset)
                }
                
                let finalPairs = try await pairsReservesIds
                print("OLOLO finalPairs \(finalPairs)")
//                
//                
//                var liquidityPairs = try await self.remotePolkaswapService.getAllPairs()
//                print("OLOLO liquidityPairs \(liquidityPairs)")
//                
//                let pairs = try await liquidityPairs.asyncMap { [weak self] pair in
//                    if let reservesId = pair.reservesId {
//                        return pair.update(reservesId: reservesId)
//                    }
//                    
//                    let reservesId = try await self?.remotePolkaswapService.getPoolReservesId(
//                        baseAssetId: pair.baseAssetId,
//                        targetAssetId: pair.targetAssetId
//                    )
//                    return pair.update(reservesId: reservesId)
//                }
//                print("OLOLO liquidityPairs1 \(pairs)")
//                
//                liquidityPairs = try await pairs.asyncMap { [weak self] pair in
//                    let apy = try await self?.remotePolkaswapService.getAPY(reservesId: pair.reservesId)
//                    return pair.update(apy: apy)
//                }
//                print("OLOLO liquidityPairs2 \(liquidityPairs)")
//                
//                let pools = liquidityPairs.compactMap { pair in
//                    let idData = NSMutableData()
//                    idData.append(Data(pair.baseAssetId.utf8))
//                    idData.append(Data(pair.targetAssetId.utf8))
//                    let poolId = String(idData.hashValue)
//                    
//                    let priceUsd = fiatData.first(where: { $0.id == pair.baseAssetId })?.priceUsd?.decimalValue ?? .zero
//                    let reserves = pair.reserves ?? Decimal(0)
//                    return ExplorePool(
//                        id: poolId,
//                        baseAssetId: pair.baseAssetId,
//                        targetAssetId: pair.targetAssetId,
//                        tvl: priceUsd * reserves * 2
//                    )
//                }
//                print("OLOLO pools \(pools)")
//                self.pools = pools
                continuation.resume(returning: [])
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
