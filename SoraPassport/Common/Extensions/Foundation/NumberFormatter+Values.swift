import Foundation
import SoraFoundation

extension NumberFormatter {
    static var vote: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.maximumFractionDigits = 0
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.roundingMode = .floor
        numberFormatter.usesGroupingSeparator = true
        return numberFormatter
    }

    static var amount: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.alwaysShowsDecimalSeparator = false
        return numberFormatter
    }
    
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }()

    static var historyAmount: NumberFormatter {
        let formatter = Self.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter
    }

    static var reward: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.roundingMode = .floor
        numberFormatter.alwaysShowsDecimalSeparator = false
        return numberFormatter
    }

    static var poolShare: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.roundingMode = .floor
        numberFormatter.alwaysShowsDecimalSeparator = false
        return numberFormatter
    }

    static var anyInteger: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.maximumFractionDigits = 0
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.roundingMode = .floor
        numberFormatter.usesGroupingSeparator = true
        return numberFormatter
    }
    
    static var fiat: NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }
    
    static var polkaswapBalance: NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }
    
    static var apy: NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 7
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }
    
    static var cryptoAssets: NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }
    
    static func inputedAmoutFormatter(with precision: UInt32) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = Int(precision)
        formatter.roundingMode = .floor
        formatter.usesGroupingSeparator = true
        formatter.alwaysShowsDecimalSeparator = false
        formatter.locale = Locale.current
        return formatter
    }
}
