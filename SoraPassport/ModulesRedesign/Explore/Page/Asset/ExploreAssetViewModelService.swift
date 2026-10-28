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
    private let priceInfoService: PriceInfoServiceProtocol
    
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
        assetInfos: [AssetInfo],
        priceInfoService: PriceInfoServiceProtocol = PriceInfoService.shared
    ) {
        self.marketCapService = marketCapService
        self.fiatService = fiatService
        self.itemFactory = itemFactory
        self.assetInfos = assetInfos
        self.priceInfoService = priceInfoService
    }
    
    func setup() async -> [ExploreAssetViewModel] {
        
        let assetIds = assetInfos.map { $0.assetId }
        let result = await priceInfoService.getPriceInfo(for: assetIds)

        // An asset without a price has no known market cap. It sorts last
        // and shows neither a price nor a market cap, never "$0".
        let prices = Self.prices(from: result.fiatData)
        let assetMarketCap = result.marketCapInfo.compactMap { asset in
            let price = prices[asset.assetId]
            return ExploreAssetLiquidity(tokenId: asset.assetId, marketCap: asset.liquidity * (price ?? 0), oldPrice: asset.hourDelta)
        }.sorted { $0.marketCap > $1.marketCap }
        
        var fullListAssets = assetMarketCap.compactMap { marketCap in
            let price = prices[marketCap.tokenId]
            
            let marketCapText: LoadingState<String> = price == nil
                ? .error
                : .loaded("$" + marketCap.marketCap.formatNumber())
            
            let deltaArributedText = LoadingState.loaded(marketCap.oldPrice.priceDeltaAttributedText())
            
            return self.itemFactory.createExploreAssetViewModel(
                with: marketCap.tokenId,
                price: price,
                deltaPrice: deltaArributedText,
                marketCap: marketCapText
            )
        }
        
        let included = Set(fullListAssets.compactMap(\.assetId))
        let missing = assetInfos.filter { !included.contains($0.assetId) }
        fullListAssets.append(contentsOf: assetViewModels(from: missing, result: result))
        for index in fullListAssets.indices {
            fullListAssets[index].serialNumber = String(index + 1)
        }
        viewModels = fullListAssets
        return fullListAssets
    }
    
    static func prices(from fiatData: [PIExactFiatData]) -> [String: Decimal] {
        var prices: [String: Decimal] = [:]
        for item in fiatData {
            if let price = item.priceUsd?.decimalValue {
                prices[item.id] = price
            }
        }
        return prices
    }

    private func assetViewModels(from assetInfos: [AssetInfo], result: PriceInfo) -> [ExploreAssetViewModel] {

        let prices = Self.prices(from: result.fiatData)
        var fullListAssets = assetInfos.sorted { $0.name.lowercased() < $1.name.lowercased() }.compactMap { assetInfo in
            // `nil` without a price: the row then shows no price at all.
            let price = prices[assetInfo.assetId]

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
