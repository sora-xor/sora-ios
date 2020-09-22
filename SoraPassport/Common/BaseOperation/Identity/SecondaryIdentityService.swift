import Foundation
import SoraKeystore

protocol SecondaryIdentityServiceProtocol {
    func createIdentity(using keystore: KeystoreProtocol, skipIfExists: Bool) throws
    func removeIdentitiy(from keystore: KeystoreProtocol) throws
    func copyIdentity(oldKeystore: KeystoreProtocol, newKeystore: KeystoreProtocol) throws
}
