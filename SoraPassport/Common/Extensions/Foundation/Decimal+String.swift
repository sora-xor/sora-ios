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
import SoraUIKit

extension Decimal {
    var stringWithPointSeparator: String {
        let separator = [NSLocale.Key.decimalSeparator: "."]
        var value = self

        return NSDecimalString(&value, separator)
    }
    
    func reduceScale(to places: Int) -> Decimal {
        let multiplier = pow(Decimal(10), places)
        let newDecimal = multiplier * self // move the decimal right
        let originalDecimal = newDecimal / multiplier // move the decimal back
        return originalDecimal
    }
    
    func formatNumber() -> String {
        let num = abs(self)
        let sign = (self < 0) ? "-" : ""

        switch num {
        case 1_000_000_000...:
            var formatted = num / 1_000_000_000
            formatted = formatted.reduceScale(to: 1)
            let text = NumberFormatter.fiat.stringFromDecimal(formatted) ?? ""
            return "\(sign)\(text)B"

        case 1_000_000...:
            var formatted = num / 1_000_000
            formatted = formatted.reduceScale(to: 1)
            let text = NumberFormatter.fiat.stringFromDecimal(formatted) ?? ""
            return "\(sign)\(text)M"

        case 1_000...:
            var formatted = num / 1_000
            formatted = formatted.reduceScale(to: 1)
            let text = NumberFormatter.fiat.stringFromDecimal(formatted) ?? ""
            return "\(sign)\(text)K"

        case 0...:
            let text = NumberFormatter.fiat.stringFromDecimal(num) ?? ""
            return "\(sign)\(text)"

        default:
            return "\(sign)\(self)"
        }
    }
    
    func assetDetailPriceText() -> String {        
        let formatter = self > 0.01 ? NumberFormatter.fiat : NumberFormatter.cryptoAssets
        
        return "$" + (formatter.stringFromDecimal(self) ?? "")
    }
    
    func priceText() -> String {
        guard !self.isZero else { return "$0" }
        
        guard let priceValueText = NumberFormatter.fiat.stringFromDecimal(self) else { return "" }

        if priceValueText == "0" {
            return "<$0.01"
        }
        
        return "$" + priceValueText
    }
    
    func priceDeltaAttributedText() -> SoramitsuAttributedText? {
        guard let percentText = NumberFormatter.percent.stringFromDecimal(self) else { return nil }

        let deltaColor: SoramitsuColor
        let sign: String
        
        switch self {
        case let x where x < 0:
            sign = "-"
            deltaColor = .statusError
        case let x where x == 0:
            sign = ""
            deltaColor = .fgPrimary
        case let x where x > 0:
            sign = "+"
            deltaColor = .statusSuccess
        default:
            sign = ""
            deltaColor = .fgPrimary
        }
        
        let isRTL = LocalizationManager.shared.isRightToLeft
        
        let deltaText = "\(sign)\(percentText)%"
        let deltaTextReversed = "%\(percentText)\(sign)"
        
        let text = isRTL ? deltaTextReversed : deltaText
        let alignment: NSTextAlignment = isRTL ? .left : .right

        let attributes = SoramitsuTextAttributes(fontData: FontType.textBoldXS, textColor: deltaColor, alignment: alignment)
        return SoramitsuTextItem(text: text, attributes: attributes)
    }
}

extension Decimal? {
    func priceText() -> String {
        guard let self else { return "" }
        return self.priceText()
    }
    
    func priceDeltaAttributedText() -> SoramitsuAttributedText? {
        guard let self else { return nil }
        return self.priceDeltaAttributedText()
    }
}
