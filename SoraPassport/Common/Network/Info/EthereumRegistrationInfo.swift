import Foundation
import BigInt

struct EthereumRegistrationInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case publicKey
        case signature
    }

    let publicKey: BigInt
    let signature: EthereumSignature

    init(publicKey: BigInt, signature: EthereumSignature) {
        self.publicKey = publicKey
        self.signature = signature
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let publicKeyString = try container.decode(String.self, forKey: .publicKey)

        guard let value = BigInt(publicKeyString) else {
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.publicKey,
                                                   in: container,
                                                   debugDescription: "")
        }

        publicKey = value

        signature = try container.decode(EthereumSignature.self, forKey: .signature)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let publicKeyString = String(publicKey)

        try container.encode(publicKeyString, forKey: .publicKey)
        try container.encode(signature, forKey: .signature)
    }
}
