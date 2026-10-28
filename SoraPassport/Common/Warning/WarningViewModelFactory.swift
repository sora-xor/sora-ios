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

import SoraUIKit

final class WarningViewModelFactory {
    func insufficientBalanceViewModel(feeAssetSymbol: String, feeAmount: Decimal, isHidden: Bool = true) -> WarningViewModel {
        let feeAmount = NumberFormatter.cryptoAssets.stringFromDecimal(feeAmount) ?? ""
        let title = R.string.localizable.commonTitleWarning(preferredLanguages: .currentLocale)
        let descriptionText = R.string.localizable.swapConfirmationScreenWarningBalanceAfterwardsTransactionIsTooSmall(feeAmount + " " + feeAssetSymbol,
                                                                                                                       preferredLanguages: .currentLocale)
        return WarningViewModel(
            title: title,
            descriptionText: descriptionText,
            isHidden: isHidden,
            containterBackgroundColor: .statusErrorContainer,
            contentColor: .statusError)
    }
    
    func poolShareStackedViewModel(isHidden: Bool = true) -> WarningViewModel {
        let descriptionText = R.string.localizable.polkaswapFarmingPoolInFarmingHint(preferredLanguages: .currentLocale)
        return WarningViewModel(
            descriptionText: descriptionText,
            isHidden: isHidden,
            containterBackgroundColor: .statusWarningContainer,
            contentColor: .statusWarning)
    }
    
    func firstLiquidityProviderViewModel(isHidden: Bool = true) -> WarningViewModel {
        let descriptionText = R.string.localizable.confirnSupplyLiquidityFirstProviderWarning(preferredLanguages: .currentLocale)
        return WarningViewModel(
            descriptionText: descriptionText,
            isHidden: isHidden,
            containterBackgroundColor: .statusWarningContainer,
            contentColor: .statusWarning)
    }
}
