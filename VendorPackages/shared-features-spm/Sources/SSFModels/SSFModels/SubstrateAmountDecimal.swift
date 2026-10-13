import BigInt
import Foundation

public struct SubstrateAmountDecimal: Equatable {
    public let decimalValue: Decimal

    public var stringValue: String {
        (decimalValue as NSNumber).stringValue
    }

    public init?(value: Decimal?) {
        guard let value else {
            return nil
        }
        decimalValue = value
    }

    public init?(string: String?) {
        guard let string,
              let value = Decimal(string: string) else
        {
            return nil
        }

        self.init(value: value)
    }

    public init?(big: BigUInt?, precision: UInt16) {
        guard let big else {
            return nil
        }
        let valueString = String(big)
        self.init(string: valueString, precision: precision)
    }

    public init?(string: String?, precision: UInt16) {
        guard let string = string,
              let decimalValue = Decimal(string: string) else
        {
            return nil
        }

        let decimal = (decimalValue as NSDecimalNumber).multiplying(byPowerOf10: -Int16(precision))
            .decimalValue
        self.init(value: decimal)
    }
}
