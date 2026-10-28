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

actor MarketCapService {
    static let shared = MarketCapService()
    private let operationManager: OperationManager = OperationManager()
    private var expiredDate: Date = Date()
    private var marketCapInfos: Set<MarketCapInfo> = []
    
    private func updateMarketCapInfo(with newValues: [MarketCapInfo]) async {
        marketCapInfos.formUnion(newValues)
    }
    
    private func updateExpiredDate() async {
        expiredDate = Date().addingTimeInterval(600)
    }
}

extension MarketCapService: MarketCapServiceProtocol {
    
    func getMarketCap(for assetIds: [String]) async -> Set<MarketCapInfo> {
        return await withCheckedContinuation { continuation in
            let searchableInfo = Set(assetIds.map { MarketCapInfo(assetId: $0) })
            let result = searchableInfo.subtracting(marketCapInfos)
            
            guard expiredDate < Date() || !result.isEmpty else {
                continuation.resume(returning: marketCapInfos)
                return
            }
            
            let findAssetIds = result.map { $0.assetId }
            
            let queryOperation = SubqueryMarketCapInfoOperation<[AssetsInfo]>(baseUrl: ConfigService.shared.config.subqueryURL, assetIds: findAssetIds)
            
            operationManager.enqueue(operations: [queryOperation], in: .transient)
            
            queryOperation.completionBlock = { [weak self] in
                guard let self = self, let response = try? queryOperation.extractNoCancellableResultData() else {
                    continuation.resume(returning: [])
                    return
                }

                let result = response.map { info in
                    let bigIntLiquidity = BigUInt(info.liquidity) ?? BigUInt(0)
                    return MarketCapInfo(
                        assetId: info.tokenId,
                        hourDelta: Decimal(Double(truncating: info.hourDelta ?? 0)),
                        liquidity: Decimal.fromSubstrateAmount(bigIntLiquidity, precision: 18) ?? 0)
                }

                Task {
                    await self.updateMarketCapInfo(with: result)
                    await self.updateExpiredDate()
                    await continuation.resume(returning: self.marketCapInfos)
                }
            }
        }
    }
}
