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
import SoraFoundation
import SoraUIKit

extension Decimal {
    /// Parse a complete, ungrouped, nonnegative user-entered amount without precision loss.
    static func parseLocalizedAmount(_ raw: String, locale: Locale) -> Decimal? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = locale.decimalSeparator ?? "."
        guard separator == "." || !text.contains(".") else { return nil }
        var normalized = ""
        for scalar in text.replacingOccurrences(of: separator, with: ".").unicodeScalars {
            if scalar == "." {
                normalized.append(".")
            } else if CharacterSet.decimalDigits.contains(scalar),
                      let digit = Character(String(scalar)).wholeNumberValue {
                normalized += String(digit)
            } else {
                return nil
            }
        }
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, let whole = parts.first,
              let value = Decimal(amountString: normalized) else { return nil }
        let integer = String(whole.drop(while: { $0 == "0" }))
        let fraction = parts.count == 2
            ? String(parts[1].reversed().drop(while: { $0 == "0" }).reversed()) : ""
        let canonical = (integer.isEmpty ? "0" : integer) + (fraction.isEmpty ? "" : "." + fraction)
        return value.stringWithPointSeparator == canonical ? value : nil
    }

    var stringWithPointSeparator: String {
        let separator = [NSLocale.Key.decimalSeparator: "."]
        var value = self

        return NSDecimalString(&value, separator)
    }
    
    func reduceScale(to places: Int) -> Decimal {
        // Match the floor rounding used by the fiat formatter. Multiplying and
        // dividing by the same power of ten leaves the original scale intact.
        rounded(with: places, mode: .down)
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
            sign = ""
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
