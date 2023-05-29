import Foundation
import SoraKeystore
@testable import SoraPassport
import SoraFoundation

final class InMemoryKeychainManager {
    let keychain = InMemoryKeychain()
}

extension InMemoryKeychainManager: SecretStoreManagerProtocol {
    func loadSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void) {
        do {
            let data = try keychain.fetchKey(for: identifier)

            completionQueue.async {
                completionBlock(data)
            }
        } catch {
            completionQueue.async {
                completionBlock(nil)
            }
        }
    }

    func saveSecret(_ secret: SecretDataRepresentable, for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        do {
            if let data = secret.asSecretData() {
                try keychain.saveKey(data, with: identifier)
            } else {
                try keychain.deleteKey(for: identifier)
            }

            completionQueue.async {
                completionBlock(true)
            }
        } catch {
            completionQueue.async {
                completionBlock(false)
            }
        }
    }

    func removeSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        do {
            try keychain.deleteKey(for: identifier)

            completionQueue.async {
                completionBlock(true)
            }
        } catch {
            completionQueue.async {
                completionBlock(false)
            }
        }
    }

    func checkSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        let result = checkSecret(for: identifier)

        completionQueue.async {
            completionBlock(result)
        }
    }

    func checkSecret(for identifier: String) -> Bool {
        return (try? keychain.checkKey(for: identifier)) ?? false
    }


}
