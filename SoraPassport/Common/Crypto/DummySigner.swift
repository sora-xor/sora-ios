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
