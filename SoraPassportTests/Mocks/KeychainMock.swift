/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
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
