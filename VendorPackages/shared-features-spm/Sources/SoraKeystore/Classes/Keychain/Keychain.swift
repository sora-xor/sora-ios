/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: GPL-3.0
 */

import Foundation
import Security

public class Keychain: KeystoreProtocol {
    /// Production wallet items have always used this non-migrating protection
    /// class. Keep it as the single typed source used by both the Security
    /// query and upgrade-safety tests; unsigned simulator test hosts cannot
    /// reliably exercise the device Keychain entitlement at runtime.
    public static let accessibility =
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String

    public init() {}

    public func addKey(_ key: Data, with identifier: String) throws {
        guard let applicationTag = identifier.data(using: String.Encoding.utf8) else {
            throw KeystoreError.invalidIdentifierFormat
        }

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
            kSecAttrAccessible as String: Self.accessibility,
            kSecValueData as String: key,
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)

        let optionalError = keystoreError(for: status)
        guard optionalError == nil else { throw optionalError! }
    }

    public func updateKey(_ key: Data, with identifier: String) throws {
        guard let applicationTag = identifier.data(using: String.Encoding.utf8) else {
            throw KeystoreError.invalidIdentifierFormat
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: key,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        let optionalError = keystoreError(for: status)
        guard optionalError == nil else { throw optionalError! }
    }

    public func fetchKey(for identifier: String) throws -> Data {
        guard let applicationTag = identifier.data(using: String.Encoding.utf8) else {
            throw KeystoreError.invalidIdentifierFormat
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
            kSecReturnData as String: kCFBooleanTrue as Any,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        let optionalError = keystoreError(for: status)
        guard optionalError == nil else { throw optionalError! }

        guard let key = item as? Data else { throw KeystoreError.unexpectedFail }

        return key
    }

    public func checkKey(for identifier: String) throws -> Bool {
        guard let applicationTag = identifier.data(using: String.Encoding.utf8) else {
            throw KeystoreError.invalidIdentifierFormat
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
            kSecReturnData as String: kCFBooleanFalse as Any,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        let optionalError = keystoreError(for: status)

        if optionalError == KeystoreError.noKeyFound { return false }

        guard optionalError == nil else { throw optionalError! }

        return true
    }

    public func allKeyIdentifiers() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecReturnAttributes as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw KeystoreError.unexpectedFail
        }

        let attributes: [[String: Any]]
        if let values = result as? [[String: Any]] {
            attributes = values
        } else if let value = result as? [String: Any] {
            attributes = [value]
        } else {
            throw KeystoreError.unexpectedFail
        }

        let identifiers = try attributes.map { item -> String in
            let value = item[kSecAttrApplicationTag as String]
            if let identifier = value as? String, !identifier.isEmpty {
                return identifier
            }
            if
                let data = value as? Data,
                let identifier = String(data: data, encoding: .utf8),
                !identifier.isEmpty
            {
                return identifier
            }
            throw KeystoreError.invalidIdentifierFormat
        }
        return Array(Set(identifiers)).sorted()
    }

    public func deleteKey(for identifier: String) throws {
        guard let applicationTag = identifier.data(using: String.Encoding.utf8) else {
            throw KeystoreError.invalidIdentifierFormat
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
        ]

        let status = SecItemDelete(query as CFDictionary)

        let optionalError = keystoreError(for: status)
        guard optionalError == nil else { throw optionalError! }
    }

    private func keystoreError(for status: OSStatus) -> KeystoreError? {
        guard status != errSecDuplicateItem else { return KeystoreError.duplicatedItem }
        guard status != errSecItemNotFound else { return KeystoreError.noKeyFound }
        guard status == errSecSuccess else { return KeystoreError.unexpectedFail }

        return nil
    }
}
