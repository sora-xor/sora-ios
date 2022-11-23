/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

enum LiquiditySourceType: String {
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
