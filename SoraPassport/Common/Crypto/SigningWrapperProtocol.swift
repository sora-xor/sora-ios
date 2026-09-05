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
        let keypairFactory = EcdsaKeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = SECSigner(privateKey: privateKey)

        let hashedData = try originalData.blake2b32()
        return try signer.sign(hashedData)
    }
}
