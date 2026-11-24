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
import BigInt

protocol SwapQuoteConverterProtocol {
    func createAmounts(fromAsset: AssetInfo, toAsset: AssetInfo, params: PolkaswapMainInteractorQuoteParams, quote: SwapValues) -> SwapQuoteAmounts?
}

/// The two amounts of a quote, in decimal units.
///
/// `fromAmount` is the amount the user entered and `toAmount` is the amount
/// the node quoted for it. With a fixed input the entered amount is in the
/// source asset and the quote in the destination asset. With a fixed output
/// it is the other way round: the user entered the amount to receive, and the
/// quote is the amount of the source asset it costs.
struct SwapQuoteAmounts: Equatable {
    let fromAmount: Decimal
    let toAmount: Decimal
    /// The decimals of the source and the destination asset the raw amounts
    /// were scaled by; nil for amounts that were not decoded from a quote.
    /// A review hands them to the signer, which signs only when the decimals
    /// it scales by are the same.
    let sourcePrecision: Int16?
    let destinationPrecision: Int16?

    init(fromAmount: Decimal, toAmount: Decimal, sourcePrecision: Int16? = nil, destinationPrecision: Int16? = nil) {
        self.fromAmount = fromAmount
        self.toAmount = toAmount
        self.sourcePrecision = sourcePrecision
        self.destinationPrecision = destinationPrecision
    }
}

extension SwapQuoteAmounts {
    /// The slippage limit of this quote as it is signed: the least received
    /// in whole units of the destination asset (fixed input), or the most
    /// sold in whole units of the source asset (fixed output). The swap
    /// screen, its details and the review all take the limit from here, with
    /// the decimals the quote was decoded with; the assets serve amounts that
    /// carry none.
    func slippageLimit(_ slippage: PolkaswapSlippage,
                       direction: SwapVariant,
                       fromAsset: AssetInfo?,
                       toAsset: AssetInfo?) -> Decimal {
        switch direction {
        case .desiredInput:
            let precision = destinationPrecision ?? toAsset.map { Int16(clamping: $0.precision) }
            return precision.map { slippage.minimumAmount(for: toAmount, precision: $0) }
                ?? slippage.minimumAmount(for: toAmount)
        case .desiredOutput:
            let precision = sourcePrecision ?? fromAsset.map { Int16(clamping: $0.precision) }
            return precision.map { slippage.maximumAmount(for: toAmount, precision: $0) }
                ?? slippage.maximumAmount(for: toAmount)
        }
    }
}

/// Swap amounts as the review and the swap details write them.
///
/// `NumberFormatter` writes at most fifteen significant digits and rounds to
/// the nearest there, whatever its rounding mode: `1.000000000000000001`
/// becomes "1" and `1.23456789012345678` becomes "1.23456789012346". So an
/// amount is first rounded here, in exact decimal arithmetic, to what the
/// formatter can write: an amount sold up, an amount received down. What is
/// written is then never better for the owner than what is signed.
enum SwapAmountText {
    static let significantDigits = 15

    static func string(_ value: Decimal, formatter: NumberFormatter, roundingUp: Bool) -> String {
        let shown = displayed(value, fractionDigits: formatter.maximumFractionDigits, roundingUp: roundingUp)
        return formatter.stringFromDecimal(shown) ?? ""
    }

    /// Beyond any amount a chain unit (u128) can hold, in either direction.
    private static let magnitudeBound = 60

    static func displayed(_ value: Decimal, fractionDigits: Int, roundingUp: Bool) -> Decimal {
        guard value.isFinite, value > 0 else { return value }
        // 10^(magnitude - 1) <= value < 10^magnitude, within the bound.
        var magnitude = 0
        var power = Decimal(1)
        if value >= 1 {
            while power <= value, magnitude < magnitudeBound { power *= 10; magnitude += 1 }
        } else {
            while value < power / 10, magnitude > -magnitudeBound { power /= 10; magnitude -= 1 }
        }
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, min(fractionDigits, significantDigits - magnitude), roundingUp ? .up : .down)
        return output
    }
}

class SwapQuoteAmountsFactory: SwapQuoteConverterProtocol {
    func createAmounts(fromAsset: AssetInfo, toAsset: AssetInfo, params: PolkaswapMainInteractorQuoteParams, quote: SwapValues) -> SwapQuoteAmounts? {
        // Each raw amount is scaled by the decimals of the asset it is in.
        // Scaling a fixed output by the source asset's decimals would show,
        // review and sign another quantity whenever the two assets differ.
        let enteredAsset = params.swapVariant == .desiredInput ? fromAsset : toAsset
        let quotedAsset = params.swapVariant == .desiredInput ? toAsset : fromAsset

        guard
            WalletAssetPrecision.isPossible(enteredAsset.precision),
            WalletAssetPrecision.isPossible(quotedAsset.precision),
            let enteredPrecision = Int16(exactly: enteredAsset.precision),
            let quotedPrecision = Int16(exactly: quotedAsset.precision),
            let enteredAmountBig = BigUInt(params.amount),
            let quotedAmountBig = BigUInt(quote.amount),
            let enteredAmount = Decimal.fromSubstrateAmount(enteredAmountBig, precision: enteredPrecision),
            let quotedAmount = Decimal.fromSubstrateAmount(quotedAmountBig, precision: quotedPrecision) else {
                return nil
        }

        let fixedInput = params.swapVariant == .desiredInput
        return SwapQuoteAmounts(fromAmount: enteredAmount,
                                toAmount: quotedAmount,
                                sourcePrecision: fixedInput ? enteredPrecision : quotedPrecision,
                                destinationPrecision: fixedInput ? quotedPrecision : enteredPrecision)
    }
}
