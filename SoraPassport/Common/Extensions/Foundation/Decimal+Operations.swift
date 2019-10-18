import Foundation

extension Decimal {
    func rounded(with scale: Int = 0, mode: Decimal.RoundingMode) -> Decimal {
        var rounding = self
        var rounded = Decimal()

        NSDecimalRound(&rounded, &rounding, scale, mode)

        return rounded
    }
}
