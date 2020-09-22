import Foundation
import RobinHood
import SoraKeystore

final class IdentityCopyOperation: BaseOperation<Void> {
    let oldKeystore: KeystoreProtocol
    let newKeystore: KeystoreProtocol

    let secondaryServices: [SecondaryIdentityServiceProtocol]

    var privateKeyStoreId: String = KeystoreKey.privateKey.rawValue
    var seedEntropyId: String = KeystoreKey.seedEntropy.rawValue

    init(oldKeystore: KeystoreProtocol,
         newKeystore: KeystoreProtocol,
         secondaryServices: [SecondaryIdentityServiceProtocol]) {
        self.oldKeystore = oldKeystore
        self.newKeystore = newKeystore
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
            let privateKey = try oldKeystore.fetchKey(for: privateKeyStoreId)
            let seedEntropy = try oldKeystore.fetchKey(for: seedEntropyId)

            try newKeystore.saveKey(privateKey, with: privateKeyStoreId)
            try newKeystore.saveKey(seedEntropy, with: seedEntropyId)

            try secondaryServices.forEach { try $0.copyIdentity(oldKeystore: oldKeystore, newKeystore: newKeystore) }

            result = .success
        } catch {
            result = .failure(error)
        }
    }
}
