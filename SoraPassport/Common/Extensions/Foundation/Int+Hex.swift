import Foundation
import BigInt

extension BigUInt {
    public init?(hexString: String, radix: Int) {
        let prefix = "0x"
        if hexString.hasPrefix(prefix) {
            let filtered = String(hexString.suffix(hexString.count - prefix.count))
            self = BigUInt(filtered, radix: radix)!
        } else {
            self = BigUInt(hexString, radix: radix)!
        }
    }
    
    static func fromHexString(_ hex: String) -> BigUInt? {
        let prefix = "0x"

        if hex.hasPrefix(prefix) {
            let filtered = String(hex.suffix(hex.count - prefix.count))
            return BigUInt(filtered, radix: 16)
        } else {
            return BigUInt(hex, radix: 16)
        }
    }
}
