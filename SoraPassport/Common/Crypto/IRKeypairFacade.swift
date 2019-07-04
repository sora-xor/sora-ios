/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import IrohaCrypto

typealias IRKeypairFacadeResult = (keypair: IRCryptoKeypairProtocol, mnemonic: IRMnemonicProtocol)

protocol IRKeypairFacadeProtocol: class {
    func createKeypair(from password: String) throws -> IRKeypairFacadeResult
    func deriveKeypair(from mnemonicPhrase: String, password: String) throws -> IRCryptoKeypairProtocol
}

extension IRKeypairFacadeProtocol {
    func createKeypair() throws -> IRKeypairFacadeResult {
        return try createKeypair(from: "")
    }

    func deriveKeypair(from mnemonicPhrase: String) throws -> IRCryptoKeypairProtocol {
        return try deriveKeypair(from: mnemonicPhrase, password: "")
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
        let mnemonicFactory = IRBIP39MnemonicCreator(language: .english)
        return IRBIP39ScryptSeedCreator(mnemonicCreator: mnemonicFactory)
    }()

    private lazy var keyFactory: IRCryptoKeyFactoryProtocol = IREd25519KeyFactory()

    func createKeypair(from password: String) throws -> IRKeypairFacadeResult {
        var optionalMnemonic: IRMnemonicProtocol?

        let seed = try seedFactory.randomSeed(with: IRKeypairFacade.mnemonicStrength,
                                              password: password,
                                              project: IRKeypairFacade.project,
                                              purpose: IRKeypairFacade.purpose,
                                              length: IRKeypairFacade.privateKeyLength,
                                              resultMnemonic: &optionalMnemonic)

        guard let mnemonic = optionalMnemonic else {
            throw IRKeypairFacadeError.invalidGeneratedMnemonic
        }

        guard let privateKey = IREd25519PrivateKey(rawData: seed) else {
            throw IRKeypairFacadeError.privateKeyCreationFailed
        }

        guard let keypair = keyFactory.derive(fromPrivateKey: privateKey) else {
            throw IRKeypairFacadeError.keypairCreationFailed
        }

        return IRKeypairFacadeResult(keypair: keypair, mnemonic: mnemonic)
    }

    func deriveKeypair(from mnemonicPhrase: String, password: String) throws -> IRCryptoKeypairProtocol {
        let seed = try seedFactory.deriveSeed(fromMnemonicPhrase: mnemonicPhrase,
                                              password: password,
                                              project: IRKeypairFacade.project,
                                              purpose: IRKeypairFacade.purpose,
                                              length: IRKeypairFacade.privateKeyLength)

        guard let privateKey = IREd25519PrivateKey(rawData: seed) else {
            throw IRKeypairFacadeError.privateKeyCreationFailed
        }

        guard let keypair = keyFactory.derive(fromPrivateKey: privateKey) else {
            throw IRKeypairFacadeError.keypairCreationFailed
        }

        return keypair
    }
}
