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
    func createAssetViewModel(with balanceData: BalanceData, fiatData: [PIExactFiatData], mode: WalletViewMode, priceDelta: Decimal? = nil) -> AssetViewModel? {
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
    
    /// The row of an asset whose balance could not be read. It keeps its
    /// place in the list and says so; it shows no amount and no value.
    func createBalanceUnavailableViewModel(assetId: String, mode: WalletViewMode) -> AssetViewModel? {
        guard let asset = walletAssets.first(where: { $0.identifier == assetId }),
              let assetInfo = assetManager.assetInfo(for: asset.identifier) else {
            return nil
        }
        var viewModel = AssetViewModel(identifier: asset.identifier,
                                       title: asset.name,
                                       subtitle: WalletUX.balanceUnavailableText,
                                       fiatText: "",
                                       icon: RemoteSerializer.shared.image(with: assetInfo.icon ?? ""),
                                       mode: mode,
                                       isFavorite: assetInfo.visible,
                                       deltaPriceText: nil)
        // Nothing more will arrive for this row: no loading placeholder.
        viewModel.priceLoadFinished = true
        return viewModel
    }

    /// The rows of an asset list, in the order of `assetIds`: one for each
    /// balance that was read, and one saying "Balance unavailable" for each
    /// asset whose balance could not be read. Such an asset is neither left
    /// out of the list nor shown as zero.
    func assetListItems(
        assetIds: [String],
        balances: [BalanceData],
        unavailable: Set<String>,
        mode: WalletViewMode,
        build: (BalanceData, AssetInfo) -> AssetViewModel?
    ) -> [AssetListItem] {
        guard !unavailable.isEmpty else {
            return balances.compactMap { item(for: $0, build: build) }
        }
        var listed = Set<String>()
        var items: [AssetListItem] = assetIds.compactMap { assetId in
            guard listed.insert(assetId).inserted else { return nil }
            if let balance = balances.first(where: { $0.identifier == assetId }) {
                return item(for: balance, build: build)
            }
            guard unavailable.contains(assetId),
                  let assetInfo = assetManager.assetInfo(for: assetId),
                  let viewModel = createBalanceUnavailableViewModel(assetId: assetId, mode: mode) else {
                return nil
            }
            let item = AssetListItem(assetInfo: assetInfo, assetViewModel: viewModel, balance: 0)
            item.balanceUnavailable = true
            return item
        }
        // A balance for an asset the caller did not name keeps its row.
        items.append(contentsOf: balances.filter { !listed.contains($0.identifier) }.compactMap { item(for: $0, build: build) })
        return items
    }

    private func item(for balance: BalanceData, build: (BalanceData, AssetInfo) -> AssetViewModel?) -> AssetListItem? {
        guard let assetInfo = assetManager.assetInfo(for: balance.identifier),
              let viewModel = build(balance, assetInfo) else {
            return nil
        }
        return AssetListItem(assetInfo: assetInfo, assetViewModel: viewModel, balance: balance.balance.decimalValue)
    }

    func createAssetViewModel(with balanceData: BalanceData, assetInfo: AssetInfo, fiatData: [PIExactFiatData], mode: WalletViewMode, priceDelta: Decimal? = nil) -> AssetViewModel? {
        
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
    
    func createAssetViewModel(with asset: AssetInfo, fiatData: [PIExactFiatData], mode: WalletViewMode, priceDelta: Decimal? = nil) -> AssetViewModel? {
        
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
