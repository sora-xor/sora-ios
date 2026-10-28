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
    func getPools(with fiatData: [PIExactFiatData]) async throws -> [ExplorePool]
}

protocol ExplorePoolsServiceOutput: AnyObject {
}

struct ExplorePool {
    let id: String
    let baseAssetId: String
    let targetAssetId: String
    var tvl: Decimal
    var apy: Decimal?
    /// False when the base asset had no price: `tvl` is then 0 only because
    /// it could not be computed, and must not be shown as "$0".
    var tvlIsKnown = true
}

final class ExplorePoolsService {

    /// One pool's reserves as read from the chain. Prices are not part of
    /// it: the value is worked out from these and the prices of the moment.
    struct ScannedPool {
        let id: String
        let baseAssetId: String
        let targetAssetId: String
        let reserves: Decimal
        /// Position in the scan (base asset, then the wallet's asset
        /// order). It orders pools of equal value.
        var order = 0
    }

    /// The reserves of every pool, read from the node once and kept for the
    /// session. One scan is a storage read per asset pair (about 1,900 on
    /// mainnet), so callers that arrive while it runs join it, and a missing
    /// or changed price never starts another one.
    private actor ReserveScan {
        private var kept: [ScannedPool] = []
        private var running: Task<[ScannedPool], Never>?

        func pools(
            scan: @escaping () async -> [ScannedPool]
        ) async -> [ScannedPool] {
            if !kept.isEmpty {
                return kept
            }
            if let running {
                return await running.value
            }
            // Unstructured on purpose: a caller that goes away does not
            // stop the scan the other callers are waiting for.
            let task = Task { await scan() }
            running = task
            let scanned = await task.value
            running = nil
            // A scan that found nothing (the node was not ready) is not
            // kept; the next call scans again.
            if !scanned.isEmpty {
                kept = scanned
            }
            return scanned
        }
    }

    private let operationManager: OperationManagerProtocol = OperationManager()
    private weak var polkaswapOperationFactory: PolkaswapNetworkOperationFactoryProtocol?
    private weak var fiatService: FiatServiceProtocol?
    private var networkFacade: WalletNetworkOperationFactoryProtocol?
    private let assetInfos: [AssetInfo]
    private let reserveScan = ReserveScan()

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

    /// The pools, valued with `fiatData`. The reserves come from the scan
    /// kept for the session; only the valuation is done again on each call.
    func getPools(with fiatData: [PIExactFiatData]) async throws -> [ExplorePool] {
        let scanned = await reserveScan.pools { [weak self] in
            await self?.scanReserves() ?? []
        }
        return Self.value(scanned, with: fiatData)
    }

    /// Values scanned pools at the given prices, highest value first. A pool
    /// whose base asset has no price keeps `tvlIsKnown == false`. Pools of
    /// equal value (all of them while no price is known) stay in the order
    /// of the scan, so the list does not reshuffle each time it is valued.
    static func value(_ scanned: [ScannedPool], with fiatData: [PIExactFiatData]) -> [ExplorePool] {
        var prices: [String: Decimal] = [:]
        for item in fiatData where prices[item.id] == nil {
            if let price = item.priceUsd?.decimalValue {
                prices[item.id] = price
            }
        }
        return scanned
            .map { pool -> (pool: ExplorePool, order: Int) in
                let knownPriceUsd = prices[pool.baseAssetId]
                let valued = ExplorePool(id: pool.id,
                                         baseAssetId: pool.baseAssetId,
                                         targetAssetId: pool.targetAssetId,
                                         tvl: (knownPriceUsd ?? .zero) * pool.reserves * 2,
                                         tvlIsKnown: knownPriceUsd != nil)
                return (valued, pool.order)
            }
            .sorted { first, second in
                if first.pool.tvl != second.pool.tvl {
                    return first.pool.tvl > second.pool.tvl
                }
                return first.order < second.order
            }
            .map(\.pool)
    }

    private func scanReserves() async -> [ScannedPool] {
        let baseAssetIds = [WalletAssetId.xor.rawValue, WalletAssetId.xstusd.rawValue]
        let targetAssetIds: [String] = assetInfos.filter { !baseAssetIds.contains($0.assetId) }.map { $0.assetId }

        let scanned = try? await collectPools(baseAssetIds: baseAssetIds, targetAssetIds: targetAssetIds).enumerated().concurrentMap({ [weak self] (order, poolTuple) -> ScannedPool? in
            var pool = await self?.scanPool(poolTuple: poolTuple)
            pool?.order = order
            return pool
        })
        return scanned ?? []
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
    
    private func scanPool(poolTuple: (baseAssetId: String, targetAssetId: String)) async -> ScannedPool? {
        return await withCheckedContinuation { continuation in
            guard let operation = try? polkaswapOperationFactory?.poolReserves(baseAsset: poolTuple.baseAssetId, targetAsset: poolTuple.targetAssetId) else {
                continuation.resume(returning: nil)
                return
            }

            operation.completionBlock = { [weak self] in
                
                guard let reserves = try? operation.extractResultData()?.underlyingValue?.reserves else {
                    continuation.resume(returning: nil)
                    return
                }
                let reservesDecimal = Decimal.fromSubstrateAmount(reserves.value, precision: 18) ?? .zero
                
                let accountId = (self?.networkFacade as? WalletNetworkFacade)?.accountSettings.accountId ?? ""
                
                let idData = NSMutableData()
                idData.append(Data(poolTuple.baseAssetId.utf8))
                idData.append(Data(poolTuple.targetAssetId.utf8))
                idData.append(Data(accountId.utf8))
                let poolId = String(idData.hashValue)
                
                continuation.resume(returning: ScannedPool(id: poolId,
                                                           baseAssetId: poolTuple.baseAssetId,
                                                           targetAssetId: poolTuple.targetAssetId,
                                                           reserves: reservesDecimal))
            }
            operationManager.enqueue(operations: [operation], in: .transient)
        }
    }
}
