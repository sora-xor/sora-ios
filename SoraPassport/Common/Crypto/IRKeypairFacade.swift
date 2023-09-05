// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
