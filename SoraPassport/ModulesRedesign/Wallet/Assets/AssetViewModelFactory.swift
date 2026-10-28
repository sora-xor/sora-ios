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

final class AssetViewModelFactory {
    let walletAssets: [AssetInfo]
    let assetManager: AssetManagerProtocol
    weak var fiatService: FiatServiceProtocol?

    init(walletAssets: [AssetInfo], assetManager: AssetManagerProtocol, fiatService: FiatServiceProtocol?) {
        self.walletAssets = walletAssets
        self.assetManager = assetManager
        self.fiatService = fiatService
    }
}

extension AssetViewModelFactory {
    func createAssetViewModel(with balanceData: BalanceData, fiatData: [FiatData], mode: WalletViewMode, priceDelta: Decimal? = nil) -> AssetViewModel? {
        guard let asset = walletAssets.first(where: { $0.identifier == balanceData.identifier }),
              let assetInfo = assetManager.assetInfo(for: asset.identifier) else {
            return nil
        }
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        let balance = (NumberFormatter.cryptoAmounts.stringFromDecimal(balanceData.balance.decimalValue) ?? "") + " " + asset.symbol
        let balanceReversed = asset.symbol + " " + (NumberFormatter.cryptoAmounts.stringFromDecimal(balanceData.balance.decimalValue) ?? "")
        var fiatText = ""
        if let priceUsd = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = balanceData.balance.decimalValue * priceUsd
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        let deltaArributedText = priceDelta?.priceDeltaAttributedText()
        
        return AssetViewModel(identifier: asset.identifier,
                              title: asset.name,
                              subtitle: isRTL ? balanceReversed : balance,
                              fiatText: fiatText,
                              icon: RemoteSerializer.shared.image(with: assetInfo.icon ?? ""),
                              mode: mode,
                              isFavorite: assetInfo.visible,
                              deltaPriceText: deltaArributedText)
    }
    
    func createAssetViewModel(with balanceData: BalanceData, assetInfo: AssetInfo, fiatData: [FiatData], mode: WalletViewMode, priceDelta: Decimal? = nil) -> AssetViewModel? {
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        let balance = (NumberFormatter.cryptoAmounts.stringFromDecimal(balanceData.balance.decimalValue) ?? "") + " " + assetInfo.symbol
        let balanceReversed = assetInfo.symbol + " " + (NumberFormatter.cryptoAmounts.stringFromDecimal(balanceData.balance.decimalValue) ?? "")
        
        var fiatText = ""
        if let priceUsd = fiatData.first(where: { $0.id == assetInfo.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = balanceData.balance.decimalValue * priceUsd
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        let deltaArributedText = priceDelta?.priceDeltaAttributedText()
        
        return AssetViewModel(identifier: assetInfo.identifier,
                              title: assetInfo.name,
                              subtitle: isRTL ? balanceReversed : balance,
                              fiatText: fiatText,
                              icon: RemoteSerializer.shared.image(with: assetInfo.icon ?? ""),
                              mode: mode,
                              isFavorite: assetInfo.visible,
                              deltaPriceText: deltaArributedText)
    }
    
    func createAssetViewModel(with asset: AssetInfo, fiatData: [FiatData], mode: WalletViewMode, priceDelta: Decimal? = nil) -> AssetViewModel? {
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        
        var fiatText = ""
        if let usdPrice = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let formatter = usdPrice > 0.01 ? NumberFormatter.fiat : NumberFormatter.cryptoAssets
            fiatText = "$" + (formatter.stringFromDecimal(usdPrice) ?? "")
        }

        let deltaArributedText = priceDelta?.priceDeltaAttributedText()

        return AssetViewModel(identifier: asset.assetId,
                              title: asset.name,
                              subtitle: asset.symbol,
                              fiatText: fiatText,
                              icon: RemoteSerializer.shared.image(with: asset.icon ?? ""),
                              mode: mode,
                              isFavorite: asset.visible,
                              deltaPriceText: deltaArributedText)
    }
}
