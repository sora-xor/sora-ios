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
import Combine
import BigInt
import SoraUIKit

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
                marketCap: .loading,
                icon: nil,
                deltaPrice: .loading
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
            
            let marketCapText = LoadingState.loaded("$" + marketCap.marketCap.formatNumber())
            
            let deltaArributedText = LoadingState.loaded(marketCap.oldPrice.priceDeltaAttributedText())
            
            return self.itemFactory.createExploreAssetViewModel(
                with: marketCap.tokenId,
                price: price,
                deltaPrice: deltaArributedText,
                marketCap: marketCapText
            )
        }
        
        (0..<fullListAssets.count).forEach { fullListAssets[$0].serialNumber += "\($0 + 1)" }
        
        if fullListAssets.isEmpty {
            return assetViewModels(from: assetInfos, result: result)
        } else {
            viewModels = fullListAssets
            return fullListAssets
        }
    }
    
    private func assetViewModels(from assetInfos: [AssetInfo], result: PriceInfo) -> [ExploreAssetViewModel] {

        var fullListAssets = assetInfos.sorted { $0.name.lowercased() < $1.name.lowercased() }.compactMap { assetInfo in
            let price = result.fiatData.first(where: { $0.id == assetInfo.assetId })?.priceUsd?.decimalValue ?? 0

            return self.itemFactory.createExploreAssetViewModel(
                with: assetInfo.assetId,
                price: price,
                deltaPrice: .error,
                marketCap: .error
            )
        }
        
        (0..<fullListAssets.count).forEach { fullListAssets[$0].serialNumber += "\($0 + 1)" }
        return fullListAssets
    }
}
