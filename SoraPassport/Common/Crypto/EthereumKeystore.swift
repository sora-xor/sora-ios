import Foundation
import SoraKeystore
import web3swift

typealias EthereumKeystoreProtocol = KeystoreProtocol & AbstractKeystore

extension Keychain: AbstractKeystore {
    public var addresses: [EthereumAddress]? {
        return nil
    }

    public var isHDKeystore: Bool {
        return true
    }

    public func UNSAFE_getPrivateKeyData(password: String, account: EthereumAddress) throws -> Data {
        try fetchKey(for: KeystoreKey.ethKey.rawValue)
    }
}

extension InMemoryKeychain: AbstractKeystore {
    public var addresses: [EthereumAddress]? {
        return nil
    }

    public var isHDKeystore: Bool {
        return false
    }

    public func UNSAFE_getPrivateKeyData(password: String, account: EthereumAddress) throws -> Data {
        try fetchKey(for: KeystoreKey.ethKey.rawValue)
    }
}
