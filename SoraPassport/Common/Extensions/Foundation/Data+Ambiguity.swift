import Foundation
import SoraCrypto

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
}
