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
import RobinHood

import SoraUIKit
import SoraFoundation
import IrohaCrypto

final class ExploreItemFactory {
    let assetManager: AssetManagerProtocol
    let localizationManager = LocalizationManager.shared

    init(assetManager: AssetManagerProtocol) {
        self.assetManager = assetManager
    }
}

extension ExploreItemFactory {
    
    func createExploreAssetViewModel(
        with assetId: String,
        price: Decimal?,
        deltaPrice: LoadingState<SoramitsuAttributedText?>,
        marketCap: LoadingState<String>
    ) -> ExploreAssetViewModel? {
        guard let assetInfo = assetManager.assetInfo(for: assetId) else { return nil }
        
        let fiatText = price.priceText()
        
        return ExploreAssetViewModel(
            assetId: assetId,
            symbol: assetInfo.symbol,
            title: assetInfo.name,
            price: fiatText,
            marketCap: marketCap,
            icon: RemoteSerializer.shared.image(with: assetInfo.icon ?? ""),
            deltaPrice: deltaPrice
        )
    }

    /// - Parameter apyLoaded: The APY read has finished. Without a rate to
    ///   show, the cell then ends its loading placeholder instead of
    ///   shimmering for good.
    func createPoolsItem(with pool: ExplorePool, serialNumber: String, apy: Decimal? = nil, apyLoaded: Bool = false) -> ExplorePoolViewModel {
        let baseAssetInfo = assetManager.assetInfo(for: pool.baseAssetId)
        let targetAssetInfo = assetManager.assetInfo(for: pool.targetAssetId)

        // The pool list is valued after the price read has finished. Without
        // a price the value is unknown: the cell shows nothing there, neither
        // "$0" nor a loading placeholder that never ends.
        let tvl: String? = pool.tvlIsKnown ? "$" + pool.tvl.formatNumber() : ""
        let apyString = localizationManager.isRightToLeft ? "%\(NumberFormatter.percent.stringFromDecimal((apy ?? .zero) * 100) ?? "") APY" : "\(NumberFormatter.percent.stringFromDecimal((apy ?? .zero) * 100) ?? "")% APY"
        let apyText: String? = apy != nil ? apyString : (apyLoaded ? "" : nil)
        
        let title = localizationManager.isRightToLeft ? "\(targetAssetInfo?.symbol ?? "??")-\(baseAssetInfo?.symbol ?? "??")" : "\(baseAssetInfo?.symbol ?? "??")-\(targetAssetInfo?.symbol ?? "??")"
        
        return ExplorePoolViewModel(poolId: pool.id.description,
                                    title: title,
                                    tvl: tvl,
                                    serialNumber: serialNumber,
                                    apy: apyText,
                                    baseAssetId: baseAssetInfo?.assetId ?? "",
                                    targetAssetId: targetAssetInfo?.assetId ?? "",
                                    baseAssetIcon: RemoteSerializer.shared.image(with: baseAssetInfo?.icon ?? ""),
                                    targetAssetIcon:  RemoteSerializer.shared.image(with: targetAssetInfo?.icon ?? ""))
    }
}
