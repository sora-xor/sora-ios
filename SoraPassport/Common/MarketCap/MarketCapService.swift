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
import sorawallet
import BigInt

struct MarketCapInfo: Hashable {
    let assetId: String
    let hourDelta: Decimal
    let liquidity: Decimal
    
    init(assetId: String,
         hourDelta: Decimal = 0,
         liquidity: Decimal = 0) {
        self.assetId = assetId
        self.hourDelta = hourDelta
        self.liquidity = liquidity
    }
    
    static func == (lhs: MarketCapInfo, rhs: MarketCapInfo) -> Bool {
        lhs.assetId == rhs.assetId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(assetId)
    }
}

protocol MarketCapServiceProtocol: AnyObject {
    func getMarketCap(for assetIds: [String]) async -> Set<MarketCapInfo>
}

/// The 24-hour change and the liquidity of assets.
///
/// The service keeps nothing of its own. Every call is worked out from the
/// shared asset catalog (`PICatalogs.assets`), the one fiat prices come
/// from, which does the caching, the single read for all callers and the
/// backoff. A second cache here once kept yesterday's 24-hour change on
/// screen for ten minutes next to today's prices: it could not tell that
/// the catalog it had sampled was a saved one, or that a live one had
/// replaced it since. Picking a few rows out of the catalog in memory costs
/// nothing worth caching.
actor MarketCapService {
    static let shared = MarketCapService()
    private let operationManager: OperationManager = OperationManager()
    private let catalog: () async throws -> [PIAsset]

    init(
        catalog: @escaping () async throws -> [PIAsset] = {
            try await PICatalogs.assets.values()
        }
    ) {
        self.catalog = catalog
    }
}

extension MarketCapService: MarketCapServiceProtocol {

    /// Market data for exactly the requested assets, from the catalog as it
    /// is now. Empty when the catalog cannot be read or does not hold every
    /// requested asset.
    func getMarketCap(for assetIds: [String]) async -> Set<MarketCapInfo> {
        // The public production entry point is non-throwing. Fail closed before
        // constructing an operation so empty, duplicate, or unbounded input
        // cannot reach the full PI asset catalog.
        guard
            (try? PIMarketCapCatalogValidator
                .validatedRequestedAssetIDs(assetIds)) != nil
        else {
            return []
        }
        return await withCheckedContinuation { continuation in
            let queryOperation = SubqueryMarketCapInfoOperation<[AssetsInfo]>(
                baseUrl: ConfigService.shared.config.subqueryURL,
                assetIds: assetIds,
                catalog: catalog
            )

            queryOperation.completionBlock = {
                guard let response = try? queryOperation.extractNoCancellableResultData() else {
                    continuation.resume(returning: [])
                    return
                }

                let result = response.compactMap { info -> MarketCapInfo? in
                    guard
                        let bigIntLiquidity = BigUInt(info.liquidity),
                        let liquidity = Decimal.fromSubstrateAmount(
                            bigIntLiquidity,
                            precision: 18
                        )
                    else {
                        return nil
                    }
                    return MarketCapInfo(
                        assetId: info.tokenId,
                        hourDelta: Decimal(Double(truncating: info.hourDelta ?? 0)),
                        liquidity: liquidity
                    )
                }
                guard result.count == response.count else {
                    // Never publish a partially converted catalog. The PI
                    // operation already required every requested asset and an
                    // exact integer liquidity; Decimal overflow or any KMM
                    // bridge contradiction invalidates the whole refresh.
                    continuation.resume(returning: [])
                    return
                }

                continuation.resume(returning: Set(result))
            }

            operationManager.enqueue(operations: [queryOperation], in: .transient)
        }
    }
}
