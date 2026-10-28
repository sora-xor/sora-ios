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
import SSFCrypto
import SSFUtils

protocol SigningWrapperProtocol: IRSignatureCreatorProtocol {}

/// Signs from the existing persisted 32-byte SORA2 child seed. The vendored
/// `EDSigner` cannot safely be used here: it retains only half of the expanded
/// key while its C implementation reads both halves. `EDSeedSigner` performs
/// the complete in-memory expansion without changing the persisted seed,
/// public key, address, or Keychain representation.
enum Sora2Ed25519SeedSigner {
    static func sign(
        _ originalData: Data,
        seed sourceSeed: Data
    ) throws -> EDSignature {
        guard sourceSeed.count == 32 || sourceSeed.count == 64 else {
            throw SigningWrapperError.keysNotVerified
        }
        var seed = sourceSeed.miniSeed
        defer {
            seed.resetBytes(in: seed.startIndex ..< seed.endIndex)
        }
        return try EDSeedSigner(seed: seed).sign(originalData)
    }
}

/// A production signer that can reuse a lifecycle lease already owned by a
/// transaction coordinator. Passing the lease explicitly keeps the selected
/// wallet stable through signing without recursively acquiring the process
/// wide wallet-mutation coordinator.
protocol LifecycleSigningWrapperProtocol: SigningWrapperProtocol {
    var signingAccount: AccountItem { get }

    func sign(
        _ originalData: Data,
        lifecycleLease: WalletLifecycleLease
    ) throws -> IRSignatureProtocol
}

extension SigningWrapperProtocol {
    func signSr25519(_ originalData: Data, secretKeyData: Data, publicKeyData: Data) throws
        -> IRSignatureProtocol {

        guard secretKeyData.count == 64, publicKeyData.count == 32 else {
            throw SigningWrapperError.keysNotVerified
        }
        let privateKey = try SNPrivateKey(rawData: secretKeyData)
        let publicKey = try SNPublicKey(rawData: publicKeyData)

        let signer = SNSigner(keypair: SNKeypair(privateKey: privateKey, publicKey: publicKey))
        let signature = try signer.sign(originalData)

        return signature
    }

    func signEd25519(_ originalData: Data, secretKey: Data) throws -> IRSignatureProtocol {
        try Sora2Ed25519SeedSigner.sign(
            originalData,
            seed: secretKey
        )
    }

    func signEcdsa(_ originalData: Data, secretKey: Data) throws -> IRSignatureProtocol {
        guard secretKey.count == 32 else { throw SigningWrapperError.keysNotVerified }
        let keypairFactory = EcdsaKeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = SECSigner(privateKey: privateKey)

        let hashedData = try originalData.blake2b32()
        return try signer.sign(hashedData)
    }
}
