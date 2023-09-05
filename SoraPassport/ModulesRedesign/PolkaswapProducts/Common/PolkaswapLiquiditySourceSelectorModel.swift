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
import SoraFoundation

enum LiquiditySourceType: String, CaseIterable {
    case smart = ""
    case xyk = "XYKPool"
    case tbc = "MulticollateralBondingCurvePool"
}

extension LiquiditySourceType: SourceType {
    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .xyk:
            return R.string.localizable.polkaswapXyk(preferredLanguages: locale.rLanguages)
        case .tbc:
            return R.string.localizable.polkaswapTbc(preferredLanguages: locale.rLanguages)
        case .smart:
            return R.string.localizable.polkaswapSmart(preferredLanguages: locale.rLanguages)
        }
    }

    var descriptionText: String? {
        let preferredLocalizations = LocalizationManager.shared.preferredLocalizations
        switch self {
        case .smart:
            return R.string.localizable.polkaswapMarketSmartDescription(preferredLanguages: preferredLocalizations)
        case .xyk:
            return R.string.localizable.polkaswapMarketXykDescription(preferredLanguages: preferredLocalizations)
        case .tbc:
            return R.string.localizable.polkaswapMarketTbcDescription(preferredLanguages: preferredLocalizations)
        }
    }

}

extension LiquiditySourceType {

    var code: [[String?]] {
        /*
        Metadata:
         - 0 : "XYKPool"
         - 1 : "BondingCurvePool"
         - 2 : "MulticollateralBondingCurvePool"
         - 3 : "MockPool"
         - 4 : "MockPool2"
         - 5 : "MockPool3"
         - 6 : "MockPool4"
         - 7 : "XSTPool"
         */
        switch self {
        case .smart:
            return []
        case .tbc:
            return [["MulticollateralBondingCurvePool", nil]]
        case .xyk:
            return [["XYKPool",nil]]
        }
    }

    init(networkValue: UInt?) {
        switch networkValue {
        case 0:
            self = .xyk
        case 2:
            self = .tbc
        default:
            self = .smart
        }
    }

    var filter: UInt {
        /*
        - 0 : "Disabled"
        - 1 : "ForbidSelected"
        - 2 : "AllowSelected"
         */
        switch self{
        case .smart:
            return 0
        default:
            return 2
        }
    }
}


class PolkaswapLiquiditySourceSelectorModel {
    var sources: [LiquiditySourceType] = []
    var selectedSource: LiquiditySourceType?
}
