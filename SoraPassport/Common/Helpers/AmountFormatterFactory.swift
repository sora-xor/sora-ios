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
import SoraFoundation

protocol AmountFormatterFactoryProtocol: NumberFormatterFactoryProtocol {
    func createTokenFormatter(for asset: WalletAsset?, maxPrecision: Int) -> LocalizableResource<TokenFormatter>
    func createDisplayFormatter(for asset: WalletAsset?, maxPrecision: Int) -> LocalizableResource<NumberFormatter>
    func createInputFormatter(for asset: AssetInfo?) -> LocalizableResource<NumberFormatter>
    func createPercentageFormatter(maxPrecision: Int) -> LocalizableResource<NumberFormatter>
    func createPolkaswapAmountFormatter() -> LocalizableResource<NumberFormatter>
}

struct AmountFormatterFactory: AmountFormatterFactoryProtocol {
    let assetPrecision: Int
    let usdPrecision: Int

    init(assetPrecision: Int = 10,
         usdPrecision: Int = 2) {
        self.assetPrecision = assetPrecision
        self.usdPrecision = usdPrecision
    }

    func createInputFormatter(for asset: AssetInfo?) -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        if let asset = asset {
            formatter.maximumFractionDigits = Int(asset.precision)
        }

        return formatter.localizableResource()
    }

    func createInputFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        if let asset = asset {
            formatter.maximumFractionDigits = Int(asset.precision)
        }

        return formatter.localizableResource()
    }

    func createDisplayFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        let precision = precision(for: asset)
        return createAssetNumberFormatter(for: precision).localizableResource()
    }

    func createDisplayFormatter(for asset: WalletAsset?, maxPrecision: Int) -> LocalizableResource<NumberFormatter> {
        var precision = precision(for: asset)
        precision = min(precision, maxPrecision)
        return createAssetNumberFormatter(for: precision).localizableResource()
    }

    func precision(for asset: WalletAsset?) -> Int {
        guard let asset = asset else {
            return assetPrecision
        }
        return Int(asset.precision)
    }

    func createTokenFormatter(for asset: WalletAsset?) -> LocalizableResource<TokenFormatter> {
        let precision = asset != nil ? Int(asset!.precision) : Int.max
        return createTokenFormatter(for: asset, maxPrecision: precision)
    }

    func createTokenFormatter(for asset: WalletAsset?, maxPrecision: Int) -> LocalizableResource<TokenFormatter> {
        var precision = asset != nil  ? Int(asset!.precision) : assetPrecision
        precision = min(precision, maxPrecision)
        let numberFormatter = createTokenNumberFormatter(for: precision)
        let tokenSymbol = asset?.symbol ?? ""
        let separator = tokenSymbol.count > 0 ? " " : ""
        let tokenFormatter = TokenFormatter(decimalFormatter: numberFormatter,
                                        tokenSymbol: tokenSymbol,
                                        separator: separator,
                                        position: .suffix)
        return LocalizableResource { locale in
            tokenFormatter.locale = locale
            return tokenFormatter
        }
    }

    func createShortFormatter(for asset: WalletAsset?)  -> LocalizableResource<TokenFormatter> {
        let precision = 4
        let numberFormatter = createTokenNumberFormatter(for: precision)
        let tokenFormatter = TokenFormatter(decimalFormatter: numberFormatter,
                                        tokenSymbol: asset?.symbol ?? "",
                                        separator: " ",
                                        position: .suffix)
        return LocalizableResource { locale in
            tokenFormatter.locale = locale
            return tokenFormatter
        }
    }

    private func createUsdNumberFormatter(for precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        formatter.maximumFractionDigits = precision

        return formatter
    }

    private func createAssetNumberFormatter(for precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = precision

        return formatter
    }

    private func createTokenNumberFormatter(for precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = precision

        return formatter
    }

    func createPercentageFormatter(maxPrecision: Int = 2) -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.percent
        formatter.maximumFractionDigits = maxPrecision
        return formatter.localizableResource()
    }

    func createPolkaswapAmountFormatter() -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.amount
        formatter.maximumFractionDigits = 8
        return formatter.localizableResource()
    }

}
