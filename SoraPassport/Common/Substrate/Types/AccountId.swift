import Foundation
import FearlessUtils
import IrohaCrypto

struct AccountId: ScaleCodable {
    let value: Data

    init(scaleDecoder: ScaleDecoding) throws {
        value = try scaleDecoder.readAndConfirm(count: 32)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        scaleEncoder.appendRaw(data: value)
    }
}

extension AccountAddress {
    var accountId: Data? {
        let addressFactory = SS58AddressFactory()
        guard let addressType = try? addressFactory.extractAddressType(from: self) else { return nil }
        return try? addressFactory.accountId(fromAddress: self, type: addressType)
    }
}
