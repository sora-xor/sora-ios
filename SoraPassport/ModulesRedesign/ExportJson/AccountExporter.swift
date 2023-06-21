import FearlessUtils

struct EncodedAccounts: Codable {
    let encoded: String
    let encoding: KeystoreEncoding
    let accounts: [Account]
}

struct Account: Codable {
    let address: String
    let meta: Meta
}

struct Meta: Codable {
    let genesisHash, name: String
    let whenCreated: Int
}

extension KeystoreEncoding {
    static let accounts: KeystoreEncoding = .init(
        content: ["batch-pkcs8"],
        type: ["scrypt", "xsalsa20-poly1305"],
        version: "3"
    )
}
