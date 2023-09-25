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

final class PoolViewModelFactory {
    let walletAssets: [AssetInfo]
    let assetManager: AssetManagerProtocol
    weak var fiatService: FiatServiceProtocol?
    
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        return formatter
    }()
    
    init(walletAssets: [AssetInfo], assetManager: AssetManagerProtocol, fiatService: FiatServiceProtocol?) {
        self.walletAssets = walletAssets
        self.assetManager = assetManager
        self.fiatService = fiatService
    }
}

extension PoolViewModelFactory {
    
    func createPoolViewModel(with pool: PoolInfo, fiatData: [FiatData], mode: WalletViewMode, priceTrend: Decimal? = nil) -> PoolViewModel? {
        guard let baseAsset = walletAssets.first(where: { $0.identifier == pool.baseAssetId  }) else { return nil }
        guard let targetAsset = walletAssets.first(where: { $0.identifier == pool.targetAssetId }) else { return nil }
        
        guard let baseAssetInfo = assetManager.assetInfo(for: baseAsset.identifier) else { return nil }
        guard let targetAssetInfo = assetManager.assetInfo(for: targetAsset.identifier) else { return nil }
        
        guard let rewardAssetInfo = assetManager.assetInfo(for: WalletAssetId.pswap.rawValue) else { return nil }

        let baseBalance = formatter.stringFromDecimal(pool.baseAssetPooledByAccount ?? Decimal(0)) ?? ""
        let targetBalance = formatter.stringFromDecimal(pool.targetAssetPooledByAccount ?? Decimal(0)) ?? ""
        
        var fiatText = ""
        if let firstPriceUsd = fiatData.first(where: { $0.id == baseAsset.identifier })?.priceUsd?.decimalValue,
           let secondPriceUsd = fiatData.first(where: { $0.id == targetAsset.identifier })?.priceUsd?.decimalValue {
            
            let fiatDecimal = (pool.baseAssetPooledByAccount ?? Decimal(0)) * firstPriceUsd + (pool.targetAssetPooledByAccount ?? Decimal(0)) * secondPriceUsd
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        var deltaArributedText: SoramitsuTextItem?
        if let priceTrend {
            let deltaText = "\(NumberFormatter.fiat.stringFromDecimal(priceTrend) ?? "")%"
            let deltaColor: SoramitsuColor = priceTrend > 0 ? .statusSuccess : .statusError
            deltaArributedText = SoramitsuTextItem(text: deltaText,
                                                   attributes: SoramitsuTextAttributes(fontData: FontType.textBoldXS,
                                                                                       textColor: deltaColor,
                                                                                       alignment: .right))
        }
        
        return PoolViewModel(identifier: pool.poolId,
                             title: "\(baseAsset.symbol)-\(targetAsset.symbol)",
                             subtitle: "\(baseBalance) \(baseAsset.symbol) - \(targetBalance) \(targetAsset.symbol)",
                             fiatText: fiatText,
                             baseAssetImage: RemoteSerializer.shared.image(with: baseAssetInfo.icon ?? ""),
                             targetAssetImage: RemoteSerializer.shared.image(with: targetAssetInfo.icon ?? ""),
                             rewardAssetImage: RemoteSerializer.shared.image(with: rewardAssetInfo.icon ?? ""),
                             mode: mode,
                             isFavorite: true,
                             deltaArributedText: deltaArributedText)
    }
}
