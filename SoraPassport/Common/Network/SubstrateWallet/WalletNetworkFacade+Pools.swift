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
        let processingOperation = AwaitOperation<[PoolDetails]> { [weak self] in
            guard let self else { throw CancellationError() }
            let accountPools = try await self.loadAccountPools()
            let details = try await self.loadPoolsDetails(accountPools: accountPools)
            return details.sorted { $0.baseAsset < $1.baseAsset }
        }
        return CompoundOperationWrapper(targetOperation: processingOperation)
    }

    private func loadAccountPools() async throws -> [String: [String]] {
        let baseAssetIds = [WalletAssetId.xor.rawValue, WalletAssetId.xstusd.rawValue]
        let pools = try await baseAssetIds.concurrentMap { baseAssetId in
            try await self.poolList(baseAssetId: baseAssetId)
        }
        return Dictionary(uniqueKeysWithValues: pools.map { ($0.assetId, $0.pools) })
    }

    private func loadPoolsDetails(accountPools: [String: [String]]) async throws -> [PoolDetails] {
        let pairs = accountPools.flatMap { base, targets in
            targets.map { (baseAsset: base, targetAsset: $0) }
        }
        return try await pairs.concurrentMap { pair in
            try await self.getPoolDetails(baseAsset: pair.baseAsset, targetAsset: pair.targetAsset)
        }
    }

    private func poolList(baseAssetId: String) async throws -> (assetId: String, pools: [String]) {
        guard let accountId = address.accountId, !accountId.isEmpty else { throw PoolError.noProperties }
        let baseAssetIdData = try Data(hexStringSSF: baseAssetId)
        let operation = try polkaswapNetworkOperationFactory.accountPools(accountId: accountId, baseAssetId: baseAssetIdData)
        let value = try await performPoolRead(operation, dependencies: [])
        return (baseAssetId, value.underlyingValue?.assetIds ?? [])
    }

    func getPoolDetails(baseAsset: String, targetAsset: String) async throws -> PoolDetails {
        try Task.checkCancellation()
        guard let accountId = address.accountId, !accountId.isEmpty,
              let baseInfo = assetManager.assetInfo(for: baseAsset),
              let targetInfo = assetManager.assetInfo(for: targetAsset),
              let basePrecision = Int16(exactly: baseInfo.precision),
              let targetPrecision = Int16(exactly: targetInfo.precision) else {
            throw PoolError.noProperties
        }
        let properties = try polkaswapNetworkOperationFactory.poolProperties(baseAsset: baseAsset, targetAsset: targetAsset)
        let providers = try polkaswapNetworkOperationFactory.poolProvidersBalance()
        providers.configurationBlock = { [weak providers] in
            do {
                guard let pool = try properties.extractResultData(throwing: PoolError.noProperties).underlyingValue else {
                    throw PoolError.noProperties
                }
                let key = try StorageKeyFactory().poolProvidersKey(reservesAccountId: pool.reservesAccountId.value, accountId: accountId)
                providers?.parameters = [key.toHex(includePrefix: true)]
            } catch { providers?.result = .failure(error) }
        }
        providers.addDependency(properties)

        let issuance = try polkaswapNetworkOperationFactory.poolTotalIssuances()
        issuance.configurationBlock = { [weak issuance] in
            do {
                guard let pool = try properties.extractResultData(throwing: PoolError.noProperties).underlyingValue else {
                    throw PoolError.noProperties
                }
                let key = try StorageKeyFactory().accountPoolTotalIssuancesKeyForId(pool.reservesAccountId.value)
                issuance?.parameters = [key.toHex(includePrefix: true)]
            } catch { issuance?.result = .failure(error) }
        }
        issuance.addDependency(properties)

        let reserves = try polkaswapNetworkOperationFactory.poolReserves(baseAsset: baseAsset, targetAsset: targetAsset)
        let farms = AwaitOperation<[UserFarm]> { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.demeterFarmingService.loadUserFarmInfos(baseAssetId: baseAsset, targetAssetId: targetAsset, accountId: accountId)
        }
        let map = ClosureOperation<PoolDetails> {
            guard let reserves = try reserves.extractResultData(throwing: PoolError.noReserves).underlyingValue,
                  let totalIssuance = try issuance.extractResultData(throwing: PoolError.noProperties).underlyingValue else {
                throw PoolError.noProperties
            }
            // Absent storage is a zero holding; a failed read must stay a failure.
            let balance = try providers.extractResultData(throwing: PoolError.noProperties).underlyingValue ?? Balance(value: 0)
            let farms = try farms.extractResultData(throwing: DemeterFarmingServiceError.unavailable)
            guard let balanceDecimal = Decimal.fromSubstrateAmount(balance.value, precision: 18),
                  let issuanceDecimal = Decimal.fromSubstrateAmount(totalIssuance.value, precision: 18),
                  let baseReserves = Decimal.fromSubstrateAmount(reserves.reserves.value, precision: basePrecision),
                  let targetReserves = Decimal.fromSubstrateAmount(reserves.fees.value, precision: targetPrecision) else {
                throw PoolError.noProperties
            }
            let fraction = totalIssuance.value > 0 ? balanceDecimal / issuanceDecimal : .zero
            return PoolDetails(baseAsset: baseAsset, targetAsset: targetAsset, yourPoolShare: fraction * 100,
                baseAssetPooledByAccount: baseReserves * fraction, targetAssetPooledByAccount: targetReserves * fraction,
                baseAssetPooledTotal: baseReserves, targetAssetPooledTotal: targetReserves,
                totalIssuances: issuanceDecimal, baseAssetReserves: baseReserves, targetAssetReserves: targetReserves,
                accountPoolBalance: balanceDecimal, farms: farms)
        }
        let dependencies: [Operation] = [properties, providers, issuance, reserves, farms]
        dependencies.forEach { map.addDependency($0) }
        return try await performPoolRead(map, dependencies: dependencies)
    }

    private func performPoolRead<T>(_ target: BaseOperation<T>, dependencies: [Operation]) async throws -> T {
        try Task.checkCancellation()
        let operations = dependencies + [target]
        let value: T = try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                target.completionBlock = { [weak target] in
                    continuation.resume(with: target?.result ?? .failure(CancellationError()))
                }
                let queue = OperationQueue()
                queue.qualityOfService = .utility
                operations.forEach { queue.addOperation($0) }
            }
        }, onCancel: {
            operations.forEach { $0.cancel() }
        })
        try Task.checkCancellation()
        return value
    }
}
