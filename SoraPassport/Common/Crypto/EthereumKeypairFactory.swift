import Foundation
import IrohaCrypto
import class web3swift.HDNode

protocol EthereumKeypairFactoryProtocol {
    func derivePrivateKey(from mnemonic: String, password: String) throws -> Data
}

extension EthereumKeypairFactoryProtocol {
    func derivePrivateKey(from entropy: Data) throws -> Data {
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy).toString()

        return try derivePrivateKey(from: mnemonic)
    }

    func derivePrivateKey(from mnemonic: String) throws -> Data {
        try derivePrivateKey(from: mnemonic, password: "")
    }
}

enum EthereumKeypairFactoryError: Error {
    case hdGeneratorFailed
    case hdDeriviationFailed
}

struct EthereumKeypairFactory: EthereumKeypairFactoryProtocol {
    static let hdPath = "m/44'/60'/0'/0/0"

    func derivePrivateKey(from mnemonic: String, password: String) throws -> Data {
        let seed = try IRBIP39SeedCreator().deriveSeed(from: mnemonic, passphrase: password)

        guard let walletGenerator = HDNode(seed: seed) else {
            throw EthereumKeypairFactoryError.hdGeneratorFailed
        }

        guard let privateKey = walletGenerator.derive(path: Self.hdPath)?.privateKey else {
            throw EthereumKeypairFactoryError.hdDeriviationFailed
        }

        return privateKey
    }
}
