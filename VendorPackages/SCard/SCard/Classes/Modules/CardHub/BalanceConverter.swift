class BalanceConverter {

    static let eurMinorUnitsCount = 100.0  // TODO: check minor units currency

    static func formatedBalance(balance: Int) -> String {
        let balanceDecimal = Decimal(Double(balance) / Self.eurMinorUnitsCount)
        let balanceString = NumberFormatter.fiat.stringFromDecimal(balanceDecimal) ?? ""
        return "€\(balanceString)"
    }
}
