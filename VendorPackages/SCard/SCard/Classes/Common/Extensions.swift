import SnapKit

extension UIView {
    func addSubview(_ view: UIView, _ closure: (_ make: ConstraintMaker) -> Void) {
        self.addSubview(view)
        view.snp.makeConstraints(closure)
    }
}

extension Locale {
    var rLanguages: [String]? {
        return [identifier]
    }
}

extension Array where Element == String {
    static var currentLocale: [String]? {
        LocalizationManager.shared.selectedLocale.rLanguages
    }
}

extension NumberFormatter {

    static var amount: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.alwaysShowsDecimalSeparator = false
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
        formatter.maximumFractionDigits = 0
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }

    public func stringFromDecimal(_ value: Decimal) -> String? {
        string(from: value as NSNumber)
    }
}
