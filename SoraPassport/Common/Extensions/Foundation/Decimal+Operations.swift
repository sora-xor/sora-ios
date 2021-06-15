import Foundation

extension Decimal {
    func rounded(with scale: Int = 0, mode: Decimal.RoundingMode) -> Decimal {
        var rounding = self
        var rounded = Decimal()

        NSDecimalRound(&rounded, &rounding, scale, mode)

        return rounded
    }

    var isWholeNumber: Bool {
        if isZero { return true }
        if !isNormal { return false }
        let rounded = self.rounded(with: 0, mode: .plain)
        return self == rounded
     }
}
