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
    func getMarketCap(for assetId: String) async -> MarketCapInfo
    func getMarketCap(for assetIds: [String]) async -> Set<MarketCapInfo>
}

final class MarketCapService {
    static let shared = MarketCapService()
    private let operationManager: OperationManager = OperationManager()
    private var expiredDate: Date = Date()
    private var marketCapInfos: Set<MarketCapInfo> = []
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
            
            queryOperation.completionBlock = { [weak self] in
                guard let self = self, let response = try? queryOperation.extractNoCancellableResultData() else {
                    continuation.resume(returning: [])
                    return
                }
                
                let result = response.map { info in
                    let bigIntLiquidity = BigUInt(info.liquidity) ?? BigUInt(0)
                    return MarketCapInfo(assetId: info.tokenId,
                                         hourDelta: Decimal(Double(truncating: info.hourDelta ?? 0)),
                                         liquidity: Decimal.fromSubstrateAmount(bigIntLiquidity, precision: 18) ?? 0)
                }
                
                self.marketCapInfos.formUnion(result)
                self.expiredDate = Date().addingTimeInterval(600)
                continuation.resume(returning: self.marketCapInfos)
            }
            
            operationManager.enqueue(operations: [queryOperation], in: .transient)
        }
    }
    
    func getMarketCap(for assetId: String) async -> MarketCapInfo {
        return await withCheckedContinuation { continuation in
            if let marketCapInfo = marketCapInfos.first(where: { $0.assetId == assetId }), expiredDate < Date() {
                continuation.resume(returning: marketCapInfo)
                return
            }
            
            let queryOperation = SubqueryMarketCapInfoOperation<[AssetsInfo]>(baseUrl: ConfigService.shared.config.subqueryURL, assetIds: [assetId])
            
            queryOperation.completionBlock = { [weak self] in
                guard let self = self, let response = try? queryOperation.extractNoCancellableResultData().first else {
                    continuation.resume(returning: MarketCapInfo(assetId: assetId))
                    return
                }
                let bigIntLiquidity = BigUInt(response.liquidity) ?? BigUInt(0)
                let marketCapInfo = MarketCapInfo(assetId: response.tokenId,
                                                  hourDelta: Decimal(Double(truncating: response.hourDelta ?? 0)),
                                                  liquidity: Decimal.fromSubstrateAmount(bigIntLiquidity, precision: 18) ?? 0)
                self.marketCapInfos.insert(marketCapInfo)
                
                self.expiredDate = Date().addingTimeInterval(600)
                continuation.resume(returning: marketCapInfo)
            }
            
            operationManager.enqueue(operations: [queryOperation], in: .transient)
        }
    }
}
