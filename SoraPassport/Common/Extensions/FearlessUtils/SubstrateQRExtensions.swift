import FearlessUtils
import Foundation
import IrohaCrypto

public struct SoraSubstrateQRInfo: Equatable {
    public let prefix: String
    public let address: String
    public let rawPublicKey: Data
    public let username: String?
    public let assetId: String
    public let amount: String?

    public init(prefix: String = SubstrateQR.prefix,
                address: String,
                rawPublicKey: Data,
                username: String?,
                assetId: String,
                amount: String?) {
        self.prefix = prefix
        self.address = address
        self.rawPublicKey = rawPublicKey
        self.username = username
        self.assetId = assetId
        self.amount = amount
    }
}

extension AddressQREncoder {

    public func encode(info: SoraSubstrateQRInfo) throws -> Data {
        let fields: [String] = [
            info.prefix,
            info.address,
            info.rawPublicKey.toHex(includePrefix: true),
            "",
            info.assetId,
            info.amount ?? ""
        ]

        let separator: String = ":"
        guard let data = fields.joined(separator: separator).data(using: .utf8) else {
            throw QREncoderError.brokenData
        }

        return data
    }
}

extension AddressQRDecoder {
    public func decode(data: Data) throws -> SoraSubstrateQRInfo {
        guard let fields = String(data: data, encoding: .utf8)?
            .components(separatedBy: separator) else {
            throw QRDecoderError.brokenFormat
        }

        guard fields.count >= 5 else {
            throw QRDecoderError.unexpectedNumberOfFields
        }

        guard fields[0] == prefix else {
            throw QRDecoderError.undefinedPrefix
        }

        let addressFactory = SS58AddressFactory()

        let address = fields[1]
        let accountId = try addressFactory.accountId(fromAddress: address, type: chainType)
        let publicKey = try Data(hexString: fields[2])

        guard publicKey.matchPublicKeyToAccountId(accountId) else {
            throw QRDecoderError.accountIdMismatch
        }

        let username = fields[3]

        let assetId = fields[4]
        
        var amount: String? = nil
        if fields.count > 5 {
            amount = fields[5]
        }

        return SoraSubstrateQRInfo(prefix: prefix,
                                   address: address,
                                   rawPublicKey: publicKey,
                                   username: username,
                                   assetId: assetId,
                                   amount: amount)
    }
}
