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

enum DummySigningType {
    case sr25519(secretKeyData: Data, publicKeyData: Data)
    case ed25519(seed: Data)
    case ecdsa(seed: Data)
}

final class DummySigner: SigningWrapperProtocol {
    let type: DummySigningType

    init(cryptoType: CryptoType, seed: Data = Data(repeating: 1, count: 32)) throws {
        switch cryptoType {
        case .sr25519:
            let keypair = try SNKeyFactory().createKeypair(fromSeed: seed)
            type = .sr25519(secretKeyData: keypair.privateKey().rawData(),
                            publicKeyData: keypair.publicKey().rawData())
        case .ed25519:
            type = .ed25519(seed: seed)
        case .ecdsa:
            type = .ecdsa(seed: seed)
        }

    }

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        switch type {
        case .sr25519(let secretKeyData, let publicKeyData):
            return try signSr25519(originalData,
                                   secretKeyData: secretKeyData,
                                   publicKeyData: publicKeyData)
        case .ed25519(let seed):
            return try signEd25519(originalData, secretKey: seed)
        case .ecdsa(let seed):
            return try signEcdsa(originalData, secretKey: seed)
        }
    }
}
