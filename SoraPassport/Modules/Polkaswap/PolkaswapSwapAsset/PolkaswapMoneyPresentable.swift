/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

protocol PolkaswapMoneyPresentable {
    var formatter: NumberFormatter { get }
    var innerAmount: String { get }
    var precision: Int16 { get }
    var additionalSet: String? { get set }

    func transform(input: String, from locale: Locale) -> String
}

protocol PercentPresentable : PolkaswapMoneyPresentable {

}

private struct MoneyPresentableConstants {
    static let singleZero = "0"
}

extension PercentPresentable {
    private func isValid(amount: String) -> Bool {
        return formatter.number(from: amount) != nil
    }

    func set(_ amount: String) -> String {
        guard amount.rangeOfCharacter(from: notEligibleSet()) == nil else {
            return self.innerAmount
        }

        if amount.hasSuffix(decimalSeparator()) {
            return amount
        }

        var settingAmount = amount.replacingOccurrences(of: groupingSeparator(),
                                                        with: "")

        if settingAmount.hasPrefix(decimalSeparator()) {
            settingAmount = "\(MoneyPresentableConstants.singleZero)\(settingAmount)"
        }

        return isValid(amount: settingAmount) ? settingAmount : self.innerAmount
    }

    func add(_ amount: String) -> String {
        guard amount.rangeOfCharacter(from: notEligibleSet()) == nil else {
            return self.innerAmount
        }

        if amount == decimalSeparator() {
            if self.innerAmount.contains(decimalSeparator()) {
                return self.innerAmount
            }
            return self.innerAmount + amount
        }

        var newAmount = (self.innerAmount + amount).replacingOccurrences(of: groupingSeparator(),
                                                                    with: "")

        if newAmount.hasPrefix(decimalSeparator()) {
            newAmount = "\(MoneyPresentableConstants.singleZero)\(newAmount)"
        }

        return isValid(amount: newAmount) ? newAmount : self.innerAmount
    }
}

extension PolkaswapMoneyPresentable {

    var formattedAmount: String? {
        guard !innerAmount.isEmpty else {
            return ""
        }

        guard innerAmount != decimalSeparator() else {
            return "0" + decimalSeparator()
        }

        guard innerAmount.last != Character(decimalSeparator()) else {
            return innerAmount
        }

        // TODO: fix max precision is only 16, but 18 needed!
        guard let decimalAmount = formatter.number(from: innerAmount) else {
            return nil
        }

        var amountFormatted = formatter.string(from: decimalAmount) ?? ""
        let separator = decimalSeparator()

        if innerAmount.hasSuffix(separator) {
            amountFormatted.append(separator)
        } else {
            let amountParts = innerAmount.components(separatedBy: separator)
            let formattedParts = amountFormatted.components(separatedBy: separator)

            if amountParts.count == 2 && formattedParts.count == 1 {
                // add tralling zeros including decimal separator
                let trallingZeros = String((0..<amountParts[1].count).map { _ in
                    Character(MoneyPresentableConstants.singleZero)
                })

                amountFormatted.append("\(separator)\(trallingZeros)")
            } else if amountParts.count == 2 && formattedParts.count == 2 {
                // check whether tralling decimal zeros were cut during formatting
                if formattedParts[1].count < amountParts[1].count {
                    let zerosCount = amountParts[1].count - formattedParts[1].count
                    let trallingZeros = String((0..<zerosCount).map { _ in
                        Character(MoneyPresentableConstants.singleZero)
                    })

                    amountFormatted.append("\(trallingZeros)")
                }
            }
        }

        return amountFormatted
    }

    fileprivate func decimalSeparator() -> String {
        return formatter.decimalSeparator!
    }
    
    fileprivate func groupingSeparator() -> String {
        return formatter.groupingSeparator!
    }

    fileprivate func percentSymbol() -> String {
        formatter.percentSymbol
    }
    
    fileprivate func notEligibleSet() -> CharacterSet {
        return CharacterSet.decimalDigits
            .union(CharacterSet(charactersIn: "\(decimalSeparator())\(groupingSeparator())")).inverted
    }

    private func isValid(amount: String) -> Bool {
        let components = amount.components(separatedBy: decimalSeparator())

        return !((precision == 0 && components.count > 1) ||
                 components.count > 2 ||
                 (components.count == 2 && components[1].count > precision))
    }

    func add(_ amount: String) -> String {
        guard amount.rangeOfCharacter(from: notEligibleSet()) == nil else {
            return self.innerAmount
        }

        if amount == decimalSeparator() {
            if self.innerAmount.contains(decimalSeparator()) {
                return self.innerAmount
            }
            return self.innerAmount + amount
        }

        var newAmount = (self.innerAmount + amount).replacingOccurrences(of: groupingSeparator(),
                                                                    with: "")

        if newAmount.hasPrefix(decimalSeparator()) {
            newAmount = "\(MoneyPresentableConstants.singleZero)\(newAmount)"
        }

        return isValid(amount: newAmount) ? newAmount : self.innerAmount
    }

    func set(_ amount: String) -> String {
        guard amount.rangeOfCharacter(from: notEligibleSet()) == nil else {
            return self.innerAmount
        }

        if amount.hasSuffix(decimalSeparator()) {
            return amount
        }

        var settingAmount = amount.replacingOccurrences(of: groupingSeparator(),
                                                        with: "")

        if settingAmount.hasPrefix(decimalSeparator()) {
            settingAmount = "\(MoneyPresentableConstants.singleZero)\(settingAmount)"
        }
        
        return isValid(amount: settingAmount) ? settingAmount : self.innerAmount
    }

    func transform(input: String, from locale: Locale) -> String {
        var result = input

        if let localeGroupingSeparator = locale.groupingSeparator {
            result = result.replacingOccurrences(of: localeGroupingSeparator, with: "")
        }

        if let localeDecimalSeparator = locale.decimalSeparator,
            localeDecimalSeparator != decimalSeparator() {
            result = result.replacingOccurrences(of: localeDecimalSeparator,
                                                 with: decimalSeparator())
        }

        return result
    }
}

