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
import RobinHood
import CommonWallet
import SoraUIKit
import SoraFoundation
import IrohaCrypto

final class ExploreItemFactory {
    let assetManager: AssetManagerProtocol

    init(assetManager: AssetManagerProtocol) {
        self.assetManager = assetManager
    }
}

extension ExploreItemFactory {
    
    func createExploreAssetViewModel(with assetId: String, price: Decimal?, deltaPrice: Decimal?, marketCap: Decimal) -> ExploreAssetViewModel? {
        guard let assetInfo = assetManager.assetInfo(for: assetId) else { return nil }

        let fiatText = price != nil ? "$" + (NumberFormatter.fiat.stringFromDecimal(price ?? .zero) ?? "") : ""
        let marketCapText = "$" + marketCap.formatNumber()
        
        var deltaArributedText: SoramitsuTextItem?
        if let deltaPrice {
            let deltaText = "\(NumberFormatter.percent.stringFromDecimal(deltaPrice) ?? "")%"
            let deltaColor: SoramitsuColor = deltaPrice > 0 ? .statusSuccess : .statusError
            deltaArributedText = SoramitsuTextItem(text: deltaText,
                                                   attributes: SoramitsuTextAttributes(fontData: FontType.textBoldXS,
                                                                                       textColor: deltaColor,
                                                                                       alignment: .right))
        }
        
        return ExploreAssetViewModel(assetId: assetId,
                                     symbol: assetInfo.symbol,
                                     title: assetInfo.name,
                                     price: fiatText,
                                     marketCap: marketCapText,
                                     icon: RemoteSerializer.shared.image(with: assetInfo.icon ?? ""),
                                     deltaPrice: deltaArributedText)
    }

    func createPoolsItem(with pool: ExplorePool, serialNumber: String, apy: Decimal? = nil) -> ExplorePoolViewModel {
        let baseAssetInfo = assetManager.assetInfo(for: pool.baseAssetId)
        let targetAssetInfo = assetManager.assetInfo(for: pool.targetAssetId)

        let tvl = "$" + pool.tvl.formatNumber()
        let apyText: String? = apy != nil ? "\(NumberFormatter.percent.stringFromDecimal((apy ?? .zero) * 100) ?? "")% APY" : nil

        return ExplorePoolViewModel(poolId: pool.id.description,
                                    title: "\(baseAssetInfo?.symbol ?? "??")-\(targetAssetInfo?.symbol ?? "??")",
                                    tvl: tvl,
                                    serialNumber: serialNumber,
                                    apy: apyText,
                                    baseAssetId: baseAssetInfo?.assetId ?? "",
                                    targetAssetId: targetAssetInfo?.assetId ?? "",
                                    baseAssetIcon: RemoteSerializer.shared.image(with: baseAssetInfo?.icon ?? ""),
                                    targetAssetIcon:  RemoteSerializer.shared.image(with: targetAssetInfo?.icon ?? ""))
    }
}
