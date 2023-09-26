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
import Combine
import BigInt

final class ExploreAssetViewModelService {
    let marketCapService: MarketCapServiceProtocol
    var fiatService: FiatServiceProtocol?
    let itemFactory: ExploreItemFactory
    var assetManager: AssetManagerProtocol
    
    @Published var viewModels: [ExploreAssetViewModel] = [ ExploreAssetViewModel(serialNumber: "1"),
                                                           ExploreAssetViewModel(serialNumber: "2"),
                                                           ExploreAssetViewModel(serialNumber: "3"),
                                                           ExploreAssetViewModel(serialNumber: "4"),
                                                           ExploreAssetViewModel(serialNumber: "5") ]
    
    init(
        marketCapService: MarketCapServiceProtocol,
        fiatService: FiatServiceProtocol?,
        itemFactory: ExploreItemFactory,
        assetManager: AssetManagerProtocol
    ) {
        self.marketCapService = marketCapService
        self.fiatService = fiatService
        self.itemFactory = itemFactory
        self.assetManager = assetManager
    }
    
    func setup() {
        Task {
            async let assetInfo = marketCapService.getMarketCap()
            
            async let fiat = fiatService?.getFiat() ?? []
            
            let result = await PoolItemInfo(fiatData: fiat, marketCapInfo: assetInfo)
            
            let assetMarketCap = result.marketCapInfo.compactMap { asset in
                let amount = BigUInt(asset.liquidity) ?? 0
                let precision = Int16(assetManager.assetInfo(for: asset.tokenId)?.precision ?? 0)
                let price = result.fiatData.first { asset.tokenId == $0.id }?.priceUsd?.decimalValue ?? 0
                let marketCap = (Decimal.fromSubstrateAmount(amount, precision: precision) ?? 0) * price
                let oldPrice = Decimal(Double(truncating: asset.hourDelta ?? 0))
                return ExploreAssetLiquidity(tokenId: asset.tokenId, marketCap: marketCap, oldPrice: oldPrice)
            }

            let sortedAssetMarketCap = assetMarketCap.sorted { $0.marketCap > $1.marketCap }
            
            let fullListAssets = sortedAssetMarketCap.enumerated().compactMap { (index, marketCap) in
                
                let price = result.fiatData.first(where: { $0.id == marketCap.tokenId })?.priceUsd?.decimalValue ?? 0
                let deltaPrice: Decimal? = marketCap.oldPrice > 0 ? (price / marketCap.oldPrice - 1) * 100 : nil
                return self.itemFactory.createExploreAssetViewModel(with: marketCap.tokenId,
                                                                    serialNumber: String(index + 1),
                                                                    price: price,
                                                                    deltaPrice: deltaPrice,
                                                                    marketCap: marketCap.marketCap)
            }
            viewModels = fullListAssets
        }
    }
}
