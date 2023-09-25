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
import XNetworking

protocol PriceTrendServiceProtocol {
    func getPriceTrend(for pool: PoolInfo, fiatData: [FiatData], marketCapInfo: [AssetsInfo]) -> Decimal
    func getPriceTrend(for assetId: String, fiatData: [FiatData], marketCapInfo: [AssetsInfo]) -> Decimal?
}

final class PriceTrendService {}

extension PriceTrendService: PriceTrendServiceProtocol {
    
    func getPriceTrend(for assetId: String, fiatData: [FiatData], marketCapInfo: [AssetsInfo]) -> Decimal? {
        let actualPrice = fiatData.first(where: { $0.id == assetId })?.priceUsd?.decimalValue ?? 0
        let oldPrice = Decimal(Double(truncating: marketCapInfo.first(where: { $0.tokenId == assetId })?.hourDelta ?? 0))
        
        if oldPrice == 0 {
            return nil
        }

        return actualPrice / oldPrice - 1
    }
    
    func getPriceTrend(for pool: PoolInfo, fiatData: [FiatData], marketCapInfo: [AssetsInfo]) -> Decimal {
        let baseAssetChangePrice = getPriceTrend(for: pool.baseAssetId, fiatData: fiatData, marketCapInfo: marketCapInfo) ?? 0
        let targetAssetChangePrice = getPriceTrend(for: pool.targetAssetId, fiatData: fiatData, marketCapInfo: marketCapInfo) ?? 0
        
        let baseAssetActualPrice = fiatData.first(where: { $0.id == pool.baseAssetId })?.priceUsd?.decimalValue ?? Decimal(0)
        let targetAssetActualPrice = fiatData.first(where: { $0.id == pool.targetAssetId })?.priceUsd?.decimalValue ?? Decimal(0)
        
        let baseAssetPooled = pool.baseAssetPooledByAccount ?? Decimal(0)
        let targetAssetPooled = pool.targetAssetPooledByAccount ?? Decimal(0)
        
        let baseAssetFiatAmount = baseAssetPooled * baseAssetActualPrice
        let targetAssetFiatAmount = targetAssetPooled * targetAssetActualPrice
        
        let actualFullAmountPoolPrice = baseAssetFiatAmount + targetAssetFiatAmount
        
        let oldBaseAssetAmount = (baseAssetActualPrice / (1 + baseAssetChangePrice)) * baseAssetPooled
        let oldTagetAssetAmount = (targetAssetActualPrice / (1 + targetAssetChangePrice)) * targetAssetPooled
                                  
        let oldFullAmountPoolPrice = oldBaseAssetAmount + oldTagetAssetAmount
        
        return (actualFullAmountPoolPrice / oldFullAmountPoolPrice - 1) * 100
    }
}
