import Foundation
import IrohaCrypto

extension SNAddressType {
    init(chain: Chain) {
        self = chain.addressType()
    }

    var chain: Chain {
        return .sora
    }
}
