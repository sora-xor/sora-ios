import Foundation
import IrohaCrypto
import SSFModels
import SSFQRService
import SSFUtils

open class AddressQRDecoder: AddressQRDecodable {
    public let chainType: ChainType
    public let separator: String
    public let prefix: String

    private lazy var addressFactory = SS58AddressFactory()

    public init(
        chainType: ChainType,
        prefix: String = SubstrateQRConstants.prefix,
        separator: String = SubstrateQRConstants.fieldsSeparator
    ) {
        self.prefix = prefix
        self.chainType = chainType
        self.separator = separator
    }

    public func decode(data: Data) throws -> QRInfo {
        guard let fields = String(data: data, encoding: .utf8)?
            .components(separatedBy: separator) else {
            throw QRDecoderError.brokenFormat
        }

        guard fields.count >= 3, fields.count <= 4 else {
            throw QRDecoderError.unexpectedNumberOfFields
        }

        guard fields[0] == prefix else {
            throw QRDecoderError.undefinedPrefix
        }

        let address = fields[1]
        let publicKey = try Data(hexStringSSF: fields[2])
        let username = fields.count > 3 ? fields[3] : nil
        var accountId: Data?
        
        if address.hasPrefix("0x") {
            return AddressQRInfo(
                address: address,
                rawPublicKey: publicKey,
                username: username
            )
        } else {
            accountId = try addressFactory.accountId(fromAddress: address, type: chainType)
        }

        guard let accountId = accountId, publicKey.matchPublicKeyToAccountId(accountId) else {
            throw QRDecoderError.accountIdMismatch
        }

        return AddressQRInfo(
            prefix: prefix,
            address: address,
            rawPublicKey: publicKey,
            username: username
        )
    }
}
