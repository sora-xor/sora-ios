/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore

final class InMemoryKeychain: KeystoreProtocol {
    private var keystore: [String: Data] = [:]

    func addKey(_ key: Data, with identifier: String) throws {
        keystore[identifier] = key
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        keystore[identifier] = key
    }

    func fetchKey(for identifier: String) throws -> Data {
        if let data = keystore[identifier] {
            return data
        } else {
            throw KeystoreError.noKeyFound
        }
    }

    func checkKey(for identifier: String) throws -> Bool {
        return keystore[identifier] != nil
    }

    func deleteKey(for identifier: String) throws {
        if try checkKey(for: identifier) {
            keystore[identifier] = nil
        } else {
            throw KeystoreError.noKeyFound
        }
    }
}

extension InMemoryKeychain: SecretStoreManagerProtocol {
    func loadSecret(for identifier: String,
                    completionQueue: DispatchQueue,
                    completionBlock: @escaping (SecretDataRepresentable?) -> Void) {
        completionQueue.async {
            completionBlock(self.keystore[identifier])
        }
    }

    func saveSecret(_ secret: SecretDataRepresentable,
                    for identifier: String,
                    completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        keystore[identifier] = secret.asSecretData()

        completionQueue.async {
            completionBlock(true)
        }
    }

    func removeSecret(for identifier: String, completionQueue: DispatchQueue,
                      completionBlock: @escaping (Bool) -> Void) {
        keystore[identifier] = nil

        completionQueue.async {
            completionBlock(true)
        }
    }

    func checkSecret(for identifier: String, completionQueue: DispatchQueue,
                     completionBlock: @escaping (Bool) -> Void) {
        let exists = keystore[identifier] != nil

        completionQueue.async {
            completionBlock(exists)
        }
    }

    func checkSecret(for identifier: String) -> Bool {
        return keystore[identifier] != nil
    }
}
