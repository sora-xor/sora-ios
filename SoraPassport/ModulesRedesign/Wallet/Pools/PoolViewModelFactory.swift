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

import SoraUIKit
import sorawallet
import SoraFoundation

final class PoolViewModelFactory {
    let walletAssets: [AssetInfo]
    let assetManager: AssetManagerProtocol
    weak var fiatService: FiatServiceProtocol?
    
    init(walletAssets: [AssetInfo], assetManager: AssetManagerProtocol, fiatService: FiatServiceProtocol?) {
        self.walletAssets = walletAssets
        self.assetManager = assetManager
        self.fiatService = fiatService
    }
}

extension PoolViewModelFactory {
    
    func createPoolViewModel(with pool: PoolInfo, fiatData: [PIExactFiatData], mode: WalletViewMode, priceTrend: Decimal? = nil) -> PoolViewModel? {
        guard let baseAsset = walletAssets.first(where: { $0.identifier == pool.baseAssetId  }) else { return nil }
        guard let targetAsset = walletAssets.first(where: { $0.identifier == pool.targetAssetId }) else { return nil }
        
        guard let baseAssetInfo = assetManager.assetInfo(for: baseAsset.identifier) else { return nil }
        guard let targetAssetInfo = assetManager.assetInfo(for: targetAsset.identifier) else { return nil }
        
        guard let rewardAssetInfo = assetManager.assetInfo(for: WalletAssetId.pswap.rawValue) else { return nil }
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        let baseBalance = NumberFormatter.cryptoAmounts.stringFromDecimal(pool.baseAssetPooledByAccount ?? Decimal(0)) ?? ""
        let targetBalance = NumberFormatter.cryptoAmounts.stringFromDecimal(pool.targetAssetPooledByAccount ?? Decimal(0)) ?? ""
        
        var fiatText = ""
        if let firstPriceUsd = fiatData.first(where: { $0.id == baseAsset.identifier })?.priceUsd?.decimalValue,
           let secondPriceUsd = fiatData.first(where: { $0.id == targetAsset.identifier })?.priceUsd?.decimalValue {
            
            let fiatDecimal = (pool.baseAssetPooledByAccount ?? Decimal(0)) * firstPriceUsd + (pool.targetAssetPooledByAccount ?? Decimal(0)) * secondPriceUsd
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        let title = isRTL ? "\(targetAsset.symbol)-\(baseAsset.symbol)" : "\(baseAsset.symbol)-\(targetAsset.symbol)"
        let subtitle = isRTL ? "\(targetAsset.symbol) \(targetBalance) - \(baseAsset.symbol) \(baseBalance)" : "\(baseBalance) \(baseAsset.symbol) - \(targetBalance) \(targetAsset.symbol)"

        var deltaArributedText: SoramitsuTextItem?
        if let priceTrend {
            let deltaText = "\(NumberFormatter.percent.stringFromDecimal(priceTrend) ?? "")%"
            let deltaColor: SoramitsuColor = priceTrend > 0 ? .statusSuccess : .statusError
            deltaArributedText = SoramitsuTextItem(text: deltaText,
                                                   attributes: SoramitsuTextAttributes(fontData: FontType.textBoldXS,
                                                                                       textColor: deltaColor,
                                                                                       alignment: .right))
        }
        
        let farmedRewardAssetsImages = pool.farms.compactMap { farm in
            RemoteSerializer.shared.image(with: assetManager.assetInfo(for: farm.rewardAssetId)?.icon ?? "")
        }
        
        return PoolViewModel(identifier: pool.poolId,
                             title: title,
                             subtitle: subtitle,
                             fiatText: fiatText,
                             baseAssetImage: RemoteSerializer.shared.image(with: baseAssetInfo.icon ?? ""),
                             targetAssetImage: RemoteSerializer.shared.image(with: targetAssetInfo.icon ?? ""),
                             rewardAssetImage: RemoteSerializer.shared.image(with: rewardAssetInfo.icon ?? ""),
                             mode: mode,
                             isFavorite: true,
                             deltaArributedText: deltaArributedText,
                             farmedRewardAssetsImages: farmedRewardAssetsImages)
    }
}
