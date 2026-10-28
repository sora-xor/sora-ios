// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation

/// Number formatting of the portfolio surfaces. The app shows USD with a "$" prefix everywhere,
/// so the portfolio does too ("the app's selected fiat currency").
enum PortfolioFormat {
    static var locale: Locale = Locale.current

    private static func formatter(minFraction: Int, maxFraction: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.usesGroupingSeparator = true
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = minFraction
        formatter.maximumFractionDigits = maxFraction
        formatter.roundingMode = .halfEven
        return formatter
    }

    static func string(_ value: Decimal, minFraction: Int, maxFraction: Int) -> String {
        formatter(minFraction: minFraction, maxFraction: maxFraction).string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    /// Digits without grouping, for an editable field.
    static func plain(_ value: Decimal, maxFraction: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        // NumberFormatter can round large NSDecimalNumber integers through a
        // Double. Editable fields must retain every unit of the Decimal value.
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, max(0, maxFraction), value < 0 ? .up : .down)
        let digits = (0...9).map { formatter.string(from: NSNumber(value: $0)) ?? String($0) }
        let text = abs(rounded).stringWithPointSeparator.map { character -> String in
            if character == "." { return formatter.decimalSeparator ?? "." }
            if let digit = character.wholeNumberValue { return digits[digit] }
            return String(character)
        }.joined()
        return (rounded < 0 ? formatter.negativePrefix : formatter.positivePrefix) + text
            + (rounded < 0 ? formatter.negativeSuffix : formatter.positiveSuffix)
    }

    /// Editable amounts are ungrouped, as produced by `plain`. Reject the whole
    /// input when it is malformed or cannot be represented exactly by Decimal.
    static func parseAmount(_ raw: String, locale: Locale) -> Decimal? {
        Decimal.parseLocalizedAmount(raw, locale: locale)
    }

    /// "$12,480.55" (always cents). Below one cent but above zero: "<$0.01".
    static func fiat(_ value: Decimal) -> String {
        if value > 0 && value <= Decimal(string: "0.005")! { return "<$0.01" }
        return "$" + string(value, minFraction: 2, maxFraction: 2)
    }

    /// The hero total split into whole part and cents: ("$12,480", ".55").
    static func fiatParts(_ value: Decimal) -> (whole: String, fraction: String) {
        let text = fiat(value)
        let separator = formatter(minFraction: 2, maxFraction: 2).decimalSeparator ?? "."
        guard !text.hasPrefix("<"), let range = text.range(of: separator, options: .backwards) else {
            return (text, "")
        }
        return (String(text[..<range.lowerBound]), String(text[range.lowerBound...]))
    }

    /// Signed fiat change: "+$148.20", "−$12.00".
    static func signedFiat(_ value: Decimal) -> String {
        let sign = value < 0 ? "−" : "+"
        return sign + fiat(abs(value))
    }

    /// Signed percent with up to two decimals: "+1.2%", "−0.8%".
    static func signedPercent(_ value: Decimal) -> String {
        let sign = value < 0 ? "−" : "+"
        return sign + string(abs(value), minFraction: 0, maxFraction: abs(value) < 10 ? 2 : 1) + "%"
    }

    /// Token amounts: up to four decimals for small values, two for large, grouping always.
    static func amount(_ value: Decimal) -> String {
        let magnitude = abs(value)
        let digits: Int
        switch magnitude {
        case 0: digits = 0
        case ..<1: digits = 6
        case ..<1_000: digits = 4
        case ..<1_000_000: digits = 2
        default: digits = 0
        }
        return string(value, minFraction: 0, maxFraction: digits)
    }

    static func amount(_ value: Decimal, symbol: String) -> String {
        amount(value) + " " + symbol
    }

    /// Whole percent of a 0...1 share; "<1%" for a sliver.
    static func share(_ share: Decimal) -> String {
        let percent = share * 100
        if percent > 0 && percent < 1 { return "<1%" }
        return string(percent, minFraction: 0, maxFraction: 0) + "%"
    }

    /// The change is flat when it rounds to 0.00 %.
    static func isFlat(_ percent: Decimal?) -> Bool {
        guard let percent else { return true }
        return abs(percent) <= Decimal(string: "0.005")!
    }

    /// A short address for rows: "cnTQ1k…X9wd".
    static func shortAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return String(address.prefix(6)) + "…" + String(address.suffix(4))
    }
}
