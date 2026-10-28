// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import IrohaCrypto

typealias IRKeypairFacadeResult = (keypair: IRCryptoKeypairProtocol, mnemonic: IRMnemonicProtocol)

protocol IRKeypairFacadeProtocol: AnyObject {
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
