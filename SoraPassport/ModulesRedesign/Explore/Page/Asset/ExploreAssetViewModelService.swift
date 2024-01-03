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
    private let assetInfos: [AssetInfo]
    
    @Published var viewModels: [ExploreAssetViewModel] = {
        let serialNumbers = Array(1...20)
        let shimmersAssetItems = serialNumbers.map {
            ExploreAssetViewModel(
                assetId: nil,
                symbol: nil,
                title: nil,
                price: nil,
                serialNumber: String($0),
                marketCap: nil,
                icon: nil,
                deltaPrice: nil
            )
        }
        return shimmersAssetItems
    }()
    
    init(
        marketCapService: MarketCapServiceProtocol,
        fiatService: FiatServiceProtocol?,
        itemFactory: ExploreItemFactory,
        assetInfos: [AssetInfo]
    ) {
        self.marketCapService = marketCapService
        self.fiatService = fiatService
        self.itemFactory = itemFactory
        self.assetInfos = assetInfos
    }
    
    func setup() async -> [ExploreAssetViewModel] {
        
        let assetIds = assetInfos.map { $0.assetId }
        let result = await PriceInfoService.shared.getPriceInfo(for: assetIds)
        
        let assetMarketCap = result.marketCapInfo.compactMap { asset in
            let price = result.fiatData.first { asset.assetId == $0.id }?.priceUsd?.decimalValue ?? 0
            return ExploreAssetLiquidity(tokenId: asset.assetId, marketCap: asset.liquidity * price, oldPrice: asset.hourDelta)
        }.sorted { $0.marketCap > $1.marketCap }
        
        var fullListAssets = assetMarketCap.compactMap { marketCap in
            let price = result.fiatData.first(where: { $0.id == marketCap.tokenId })?.priceUsd?.decimalValue ?? 0
            let deltaPrice: Decimal? = marketCap.oldPrice > 0 ? (price / marketCap.oldPrice - 1) * 100 : nil
            return self.itemFactory.createExploreAssetViewModel(with: marketCap.tokenId,
                                                                price: price,
                                                                deltaPrice: deltaPrice,
                                                                marketCap: marketCap.marketCap)
        }
        
        (0..<fullListAssets.count).forEach { fullListAssets[$0].serialNumber += "\($0 + 1)" }
        
        if fullListAssets.isEmpty {
            return await setup()
        } else {
            viewModels = fullListAssets
            return fullListAssets
        }
    }
}
