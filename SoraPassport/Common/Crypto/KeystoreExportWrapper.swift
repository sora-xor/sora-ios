import Foundation
import SoraKeystore
import FearlessUtils
import IrohaCrypto
import TweetNacl

protocol KeystoreExportWrapperProtocol {
    func export(account: AccountItem, password: String?) throws -> Data
    func export(accounts: [AccountItem], password: String?) throws -> Data
}

enum KeystoreExportWrapperError: Error {
    case missingSecretKey
}

final class KeystoreExportWrapper: KeystoreExportWrapperProtocol {

    let keystore: KeystoreProtocol

    private lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private lazy var ss58Factory = SS58AddressFactory()

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    func export(account: AccountItem, password: String?) throws -> Data {
        let definition: KeystoreDefinition = try export(account: account, password: password)
        return try jsonEncoder.encode(definition)
    }

    func export(account: AccountItem, password: String?) throws -> KeystoreDefinition {
        guard let secretKey = try keystore.fetchSecretKeyForAddress(account.address) else {
            throw KeystoreExportWrapperError.missingSecretKey
        }

        let addressType = try ss58Factory.type(fromAddress: account.address)

        var builder = KeystoreBuilder()
            .with(name: account.username)

        let genesisHash = SNAddressType(addressType.uint8Value).chain.genesisHash()
        if let genesisHashData = try? Data(hexString: genesisHash) {
            builder = builder.with(genesisHash: genesisHashData.toHex(includePrefix: true))
        }

        let keystoreData = KeystoreData(address: account.address,
                                        secretKeyData: secretKey,
                                        publicKeyData: account.publicKeyData,
                                        cryptoType: account.cryptoType.utilsType)

        let definition = try builder.build(from: keystoreData, password: password, isEthereum: false)

        return definition
    }

    func export(accounts: [AccountItem], password: String?) throws -> Data {

        var encriptedAccounts: [KeystoreDefinition] = []

        try accounts.forEach {
            let definition: KeystoreDefinition = try export(account: $0, password: password)
            encriptedAccounts.append(definition)
        }

        let scryptParameters = try ScryptParameters()

        let scryptData: Data

        if let password = password {
            guard let passwordData = password.data(using: .utf8) else {
                throw KeystoreExtractorError.invalidPasswordFormat
            }
            scryptData = passwordData
        } else {
            scryptData = Data()
        }

        let encryptionKey = try IRScryptKeyDeriviation()
            .deriveKey(
                from: scryptData,
                salt: scryptParameters.salt,
                scryptN: UInt(scryptParameters.scryptN),
                scryptP: UInt(scryptParameters.scryptP),
                scryptR: UInt(scryptParameters.scryptR),
                length: UInt(KeystoreConstants.encryptionKeyLength)
            )

        let nonce = try Data.generateRandomBytes(of: KeystoreConstants.nonceLength)

        let encriptedAccountsJsonData = try jsonEncoder.encode(encriptedAccounts)
        let encrypted = try NaclSecretBox.secretBox(message: encriptedAccountsJsonData, nonce: nonce, key: encryptionKey)
        let encoded = scryptParameters.encode() + nonce + encrypted

        let accountsMeta = try accounts.map {
            let addressType = try ss58Factory.type(fromAddress: $0.address)
            let genesisHash = SNAddressType(addressType.uint8Value).chain.genesisHash()
            return Account(
                address: $0.address,
                meta: .init(genesisHash: genesisHash, name: $0.username, whenCreated: 0)
            )
        }

        let encodedAccounts = EncodedAccounts(
            encoded: encoded.base64EncodedString(),
            encoding: .accounts,
            accounts: accountsMeta
        )

        return try jsonEncoder.encode(encodedAccounts)
    }
}

enum RandomDataError: Error {
    case generatorFailed
}

extension Data {
    static func generateRandomBytes(of length: Int) throws -> Data {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw RandomDataError.generatorFailed
        }

        return data
    }
}
