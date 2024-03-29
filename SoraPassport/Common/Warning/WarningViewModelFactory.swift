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
