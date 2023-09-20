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
import CommonWallet
import SoraUIKit
import XNetworking
import SoraFoundation

final class AssetViewModelFactory {
    let walletAssets: [AssetInfo]
    let assetManager: AssetManagerProtocol
    weak var fiatService: FiatServiceProtocol?
    
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }()

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

        let balance = (formatter.stringFromDecimal(balanceData.balance.decimalValue) ?? "") + " " + asset.symbol
        var fiatText = ""
        if let priceUsd = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = balanceData.balance.decimalValue * priceUsd
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        var deltaArributedText: SoramitsuTextItem?
        if let priceDelta {
            let deltaText = "\(NumberFormatter.fiat.stringFromDecimal(priceDelta) ?? "")%"
            let deltaColor: SoramitsuColor = priceDelta > 0 ? .statusSuccess : .statusError
            deltaArributedText = SoramitsuTextItem(text: deltaText,
                                                   attributes: SoramitsuTextAttributes(fontData: FontType.textBoldXS,
                                                                                       textColor: deltaColor,
                                                                                       alignment: .right))
        }
        
        
        return AssetViewModel(identifier: asset.identifier,
                              title: asset.name,
                              subtitle: balance,
                              fiatText: fiatText,
                              icon: RemoteSerializer.shared.image(with: assetInfo.icon ?? ""),
                              mode: mode,
                              isFavorite: assetInfo.visible,
                              deltaPriceText: deltaArributedText)
    }
    
    func createAssetViewModel(with asset: AssetInfo, fiatData: [FiatData], mode: WalletViewMode, priceDelta: Decimal? = nil) -> AssetViewModel? {
        var fiatText = ""
        if let usdPrice = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let formatter = usdPrice > 0.01 ? NumberFormatter.fiat : NumberFormatter.cryptoAssets
            fiatText = "$" + (formatter.stringFromDecimal(usdPrice) ?? "")
        }

        return AssetViewModel(identifier: asset.assetId,
                              title: asset.name,
                              subtitle: asset.symbol,
                              fiatText: fiatText,
                              icon: RemoteSerializer.shared.image(with: asset.icon ?? ""),
                              mode: mode,
                              isFavorite: asset.visible)
    }
}
