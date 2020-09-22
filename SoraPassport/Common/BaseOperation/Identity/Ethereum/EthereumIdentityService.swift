import Foundation
import SoraKeystore

struct EthereumIdentityService: SecondaryIdentityServiceProtocol {
    let storeId: KeystoreKey
    let entropyId: KeystoreKey

    init(storeId: KeystoreKey = KeystoreKey.ethKey, entropyId: KeystoreKey = KeystoreKey.seedEntropy) {
        self.storeId = storeId
        self.entropyId = entropyId
    }

    func createIdentity(using keystore: KeystoreProtocol, skipIfExists: Bool) throws {
        if skipIfExists, try keystore.checkKey(for: storeId.rawValue) {
            return
        }

        let entropy = try keystore.fetchKey(for: entropyId.rawValue)

        let privateKey = try EthereumKeypairFactory().derivePrivateKey(from: entropy)

        try keystore.saveKey(privateKey, with: storeId.rawValue)
    }

    func removeIdentitiy(from keystore: KeystoreProtocol) throws {
        try keystore.deleteKeyIfExists(for: storeId.rawValue)
    }

    func copyIdentity(oldKeystore: KeystoreProtocol, newKeystore: KeystoreProtocol) throws {
        let value = try oldKeystore.fetchKey(for: storeId.rawValue)
        try newKeystore.saveKey(value, with: storeId.rawValue)
    }
}
