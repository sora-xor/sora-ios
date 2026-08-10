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

actor MarketCapService {
    static let shared = MarketCapService()
    private let operationManager: OperationManager = OperationManager()
    private var expiredDate: Date = Date()
    private var marketCapInfos: Set<MarketCapInfo> = []
    
    private func updateMarketCapInfo(with newValues: [MarketCapInfo]) async {
        // MarketCapInfo identity is assetId-only, so formUnion would retain the
        // stale equal member instead of replacing its liquidity and delta.
        for newValue in newValues {
            marketCapInfos.update(with: newValue)
        }
    }
    
    private func updateExpiredDate() async {
        expiredDate = Date().addingTimeInterval(600)
    }
}

extension MarketCapService: MarketCapServiceProtocol {
    
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
            let searchableInfo = Set(assetIds.map { MarketCapInfo(assetId: $0) })
            let result = searchableInfo.subtracting(marketCapInfos)
            let cacheExpired = expiredDate < Date()
            
            guard cacheExpired || !result.isEmpty else {
                continuation.resume(returning: marketCapInfos)
                return
            }
            
            // Refresh the complete non-empty requested subset after expiry.
            // Query only missing identities while the cache is still fresh.
            let findAssetIds = cacheExpired
                ? assetIds
                : result.map { $0.assetId }
            
            let queryOperation = SubqueryMarketCapInfoOperation<[AssetsInfo]>(baseUrl: ConfigService.shared.config.subqueryURL, assetIds: findAssetIds)

            queryOperation.completionBlock = { [weak self] in
                guard let self = self, let response = try? queryOperation.extractNoCancellableResultData() else {
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

                Task {
                    await self.updateMarketCapInfo(with: result)
                    await self.updateExpiredDate()
                    await continuation.resume(returning: self.marketCapInfos)
                }
            }

            operationManager.enqueue(operations: [queryOperation], in: .transient)
        }
    }
}
