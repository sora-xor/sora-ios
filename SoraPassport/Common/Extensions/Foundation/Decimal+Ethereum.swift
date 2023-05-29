import Foundation
import BigInt

extension Decimal {
    static func fromEthereumAmount(_ value: BigUInt) -> Decimal? {
        let valueString = String(value)

        guard let decimalValue = Decimal(string: valueString) else {
            return nil
        }

        return (decimalValue as NSDecimalNumber).multiplying(byPowerOf10: -18).decimalValue
    }

    func toEthereumAmount() -> BigUInt? {
        let valueString = (self as NSDecimalNumber).multiplying(byPowerOf10: 18).stringValue
        return BigUInt(valueString)
    }
}
