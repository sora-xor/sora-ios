import Foundation
//import SoraCrypto

/**
 *  Due to the fact that multiple libraries implement the same extension
 *  we need to fix the implementation to avoid conflict during linkage.
 */

extension Data {
    var soraHex: String {
        (self as NSData).toHexString()
    }

    var soraHexWithPrefix: String {
        let hexString = soraHex
        return "0x\(hexString)"
    }

    init(hex: String) throws {
        let prefix = "0x"
        if hex.hasPrefix(prefix) {
            let filtered = String(hex.suffix(hex.count - prefix.count))
            self = (try NSData(hexString: filtered)) as Data
        } else {
            self = (try NSData(hexString: hex)) as Data
        }
    }
}
