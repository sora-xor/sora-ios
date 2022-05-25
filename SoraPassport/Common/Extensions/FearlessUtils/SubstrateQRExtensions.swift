import FearlessUtils
import Foundation
import IrohaCrypto

public struct SoraSubstrateQRInfo: Equatable {
    public let prefix: String
    public let address: String
    public let rawPublicKey: Data
    public let username: String?
    public let assetId: String

    public init(prefix: String = SubstrateQR.prefix,
                address: String,
                rawPublicKey: Data,
                username: String?,
                assetId: String) {
        self.prefix = prefix
        self.address = address
        self.rawPublicKey = rawPublicKey
        self.username = username
        self.assetId = assetId
    }
}

extension SubstrateQREncoder {

    public func encode(info: SoraSubstrateQRInfo) throws -> Data {
        let fields: [String] = [
            info.prefix,
            info.address,
            info.rawPublicKey.toHex(includePrefix: true),
            "",
            info.assetId
        ]

        let separator: String = ":"

        guard let data = fields.joined(separator: separator).data(using: .utf8) else {
            throw SubstrateQREncoderError.brokenData
        }

        return data
    }
}

extension  SubstrateQRDecoder {
    public func decode(data: Data) throws -> SoraSubstrateQRInfo {
        guard let fields = String(data: data, encoding: .utf8)?
            .components(separatedBy: separator) else {
            throw SubstrateQRDecoderError.brokenFormat
        }

        guard fields.count == 5 else {
            throw SubstrateQRDecoderError.unexpectedNumberOfFields
        }

        guard fields[0] == prefix else {
            throw SubstrateQRDecoderError.undefinedPrefix
        }

        let addressFactory = SS58AddressFactory()

        let address = fields[1]
        let accountId = try addressFactory.accountId(fromAddress: address, type: chainType)
        let publicKey = try Data(hexString: fields[2])

        guard publicKey.matchPublicKeyToAccountId(accountId) else {
            throw SubstrateQRDecoderError.accountIdMismatch
        }

        let username = fields[3]

        let assetId = fields[4]

        return SoraSubstrateQRInfo(prefix: prefix,
                               address: address,
                               rawPublicKey: publicKey,
                               username: username,
                               assetId: assetId)
    }
}
