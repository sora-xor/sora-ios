import Foundation
import SoraKeystore
import RobinHood

final class IdentityLocalRemoveOperation: BaseOperation<Bool> {
    let keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol

    let secondaryServices: [SecondaryIdentityServiceProtocol]

    var privateKeyStoreId: String = KeystoreKey.privateKey.rawValue
    var seedEntropyId: String = KeystoreKey.seedEntropy.rawValue
    var decentralizedIdKey: String = SettingsKey.decentralizedId.rawValue
    var publicKeyIdKey = SettingsKey.publicKeyId.rawValue

    init(keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         secondaryServices: [SecondaryIdentityServiceProtocol]) {
        self.keystore = keystore
        self.settings = settings
        self.secondaryServices = secondaryServices
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            try keystore.deleteKeyIfExists(for: privateKeyStoreId)
            try keystore.deleteKeyIfExists(for: seedEntropyId)
            settings.removeValue(for: decentralizedIdKey)
            settings.removeValue(for: publicKeyIdKey)

            try secondaryServices.forEach { try $0.removeIdentitiy(from: keystore) }

            result = .success(true)
        } catch {
            result = .failure(error)
        }
    }
}
