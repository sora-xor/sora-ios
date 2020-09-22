import Foundation

extension NSDecimalNumberHandler {
    static func walletHandler(precision: Int16) -> NSDecimalNumberHandler {
        NSDecimalNumberHandler(roundingMode: .up,
                               scale: precision,
                               raiseOnExactness: false,
                               raiseOnOverflow: true,
                               raiseOnUnderflow: true,
                               raiseOnDivideByZero: true)
    }
}
