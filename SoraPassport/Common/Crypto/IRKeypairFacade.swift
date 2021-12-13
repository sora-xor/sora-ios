import Foundation
import IrohaCrypto

typealias IRKeypairFacadeResult = (keypair: IRCryptoKeypairProtocol, mnemonic: IRMnemonicProtocol)

protocol IRKeypairFacadeProtocol: class {
//    func createKeypair(from password: String) throws -> IRKeypairFacadeResult
    func deriveKeypair(from mnemonic: String, password: String) throws -> IRCryptoKeypairProtocol
}

extension IRKeypairFacadeProtocol {
//    func createKeypair() throws -> IRKeypairFacadeResult {
//        return try createKeypair(from: "")
//    }
//
    func deriveKeypair(from mnemonic: String) throws -> IRCryptoKeypairProtocol {
        return try deriveKeypair(from: mnemonic, password: "")
    }
}

enum IRKeypairFacadeError: Error {
    case invalidGeneratedMnemonic
    case keypairCreationFailed
    case privateKeyCreationFailed
}

final class IRKeypairFacade: IRKeypairFacadeProtocol {
    static let project = "SORA"
    static let purpose = "iroha keypair"
    static let mnemonicStrength: IRMnemonicStrength = .entropy160
    static let privateKeyLength: UInt = 32

    private lazy var seedFactory: IRSeedCreatorProtocol = {
        let mnemonicFactory = IRMnemonicCreator(language: .english)
        let keyDeriviation = IRScryptKeyDeriviation()
        return IRSeedCreator(mnemonicCreator: mnemonicFactory, keyDeriviation: keyDeriviation)
    }()

    private lazy var keyFactory: IRCryptoKeyFactoryProtocol = IRIrohaKeyFactory()

    func deriveKeypair(from mnemonic: String, password: String) throws -> IRCryptoKeypairProtocol {
        let seed = try seedFactory.deriveSeed(fromMnemonicPhrase: mnemonic,
                                              password: password,
                                              project: IRKeypairFacade.project,
                                              purpose: IRKeypairFacade.purpose,
                                              length: IRKeypairFacade.privateKeyLength)

        guard let privateKey = try? IRIrohaPrivateKey(rawData: seed) else {
            throw IRKeypairFacadeError.privateKeyCreationFailed
        }

        guard let keypair = try? keyFactory.derive(fromPrivateKey: privateKey) else {
            throw IRKeypairFacadeError.keypairCreationFailed
        }

        return keypair
    }
}
