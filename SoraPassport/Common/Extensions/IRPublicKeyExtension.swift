import Foundation
import IrohaCrypto

extension IRPublicKeyProtocol {
    var decentralizedUsername: String {
        return String(rawData().soraHex.prefix(20))
    }
}
