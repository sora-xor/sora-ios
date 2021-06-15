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

}
