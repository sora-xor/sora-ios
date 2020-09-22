import Foundation
@testable import SoraPassport
import SoraKeystore

struct SecondaryIdentityRepository {
    let keystore: KeystoreProtocol

    func checkAllExist() throws -> Bool {
        return try keystore.checkKey(for: KeystoreKey.ethKey.rawValue)
    }

    func checkAllEmpty() throws -> Bool {
        return try !keystore.checkKey(for: KeystoreKey.ethKey.rawValue)
    }

    func fetchAll() throws -> [Data] {
        return [
            try keystore.fetchKey(for: KeystoreKey.ethKey.rawValue)
        ]
    }

    func generateAndSaveForAll() throws {
        let data = Data(repeating: 0, count: 32)

        try keystore.saveKey(data, with: KeystoreKey.ethKey.rawValue)
    }

    func clear() throws {
        try keystore.deleteKeyIfExists(for: KeystoreKey.ethKey.rawValue)
    }
}
