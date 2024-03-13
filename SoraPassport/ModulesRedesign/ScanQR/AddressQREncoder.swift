import Foundation
import IrohaCrypto
import SSFQRService

open class AddressQREncoder: AddressQREncodable {
    let separator: String

    public init(separator: String = SubstrateQRConstants.fieldsSeparator) {
        self.separator = separator
    }

    public func encode(info: AddressQRInfo) throws -> Data {
        var fields: [String] = [
            info.prefix,
            info.address,
            info.rawPublicKey.toHex(includePrefix: true)
        ]

        if let username = info.username {
            fields.append(username)
        }

        guard let data = fields.joined(separator: separator).data(using: .utf8) else {
            throw QREncoderError.brokenData
        }

        return data
    }
}
