import Foundation

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
            return "\(self)"

        default:
            return "\(sign)\(self)"
        }
    }
}
