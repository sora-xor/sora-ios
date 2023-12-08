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
import SSFUtils
import IrohaCrypto
import RobinHood
import SoraKeystore

protocol AccountOperationFactoryProtocol {
    func newAccountOperation(request: AccountCreationRequest,
                             mnemonic: IRMnemonicProtocol) -> BaseOperation<AccountItem>

    func newAccountOperation(request: AccountImportSeedRequest) -> BaseOperation<AccountItem>

    func newAccountOperation(request: AccountImportKeystoreRequest) -> BaseOperation<AccountItem>
}

final class AccountOperationFactory: AccountOperationFactoryProtocol {
    private(set) var keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    func newAccountOperation(request: AccountCreationRequest,
                             mnemonic: IRMnemonicProtocol) -> BaseOperation<AccountItem> {
        ClosureOperation {
            let junctionResult: JunctionResult?

            if !request.derivationPath.isEmpty {
                let junctionFactory = SubstrateJunctionFactory()
                junctionResult = try junctionFactory.parse(path: request.derivationPath)
            } else {
                junctionResult = nil
            }

            let password = junctionResult?.password ?? ""

            let seedFactory = SeedFactory()
            let result = try seedFactory.deriveSeed(from: mnemonic.toString(),
                                                    password: password)

            let keypairFactory = self.createKeypairFactory(request.cryptoType)

            let chaincodes = junctionResult?.chaincodes ?? []
            let keypair = try keypairFactory.createKeypairFromSeed(result.seed.miniSeed,
                                                                   chaincodeList: chaincodes)

            let addressFactory = SS58AddressFactory()
            let address = try addressFactory.address(fromAccountId: keypair.publicKey().rawData(),
                                                     type: SNAddressType(chain: request.type))

            let secretKey: Data

            switch request.cryptoType {
            case .sr25519:
                secretKey = keypair.privateKey().rawData()
            case .ed25519:
                let derivableSeedFactory = Ed25519KeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(result.seed.miniSeed,
                                                                               chaincodeList: chaincodes)
            case .ecdsa:
                let derivableSeedFactory = EcdsaKeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(result.seed.miniSeed,
                                                                               chaincodeList: chaincodes)
            }

            try self.keystore.saveSecretKey(secretKey, address: address)
            try self.keystore.saveEntropy(result.mnemonic.entropy(), address: address)

            if !request.derivationPath.isEmpty {
                try self.keystore.saveDeriviation(request.derivationPath, address: address)
            }

            try self.keystore.saveSeed(result.seed.miniSeed, address: address)

            let settings = AccountSettings(visibleAssetIds: [], orderedAssetIds: [])

            return AccountItem(address: address,
                               cryptoType: request.cryptoType,
                               networkType: SNAddressType(chain: request.type),
                               username: request.username,
                               publicKeyData: keypair.publicKey().rawData(),
                               settings: settings,
                               order: 0,
                               isSelected: true)
        }
    }

    func newAccountOperation(request: AccountImportSeedRequest) -> BaseOperation<AccountItem> {
        ClosureOperation {
            let seed = try Data(hexStringSSF: request.seed)

            let junctionResult: JunctionResult?

            if !request.derivationPath.isEmpty {
                let junctionFactory = SubstrateJunctionFactory()
                junctionResult = try junctionFactory.parse(path: request.derivationPath)
            } else {
                junctionResult = nil
            }

            let keypairFactory = self.createKeypairFactory(request.cryptoType)

            let chaincodes = junctionResult?.chaincodes ?? []
            let keypair = try keypairFactory.createKeypairFromSeed(seed,
                                                                   chaincodeList: chaincodes)

            let addressFactory = SS58AddressFactory()
            let address = try addressFactory.address(fromAccountId: keypair.publicKey().rawData(),
                                                     type: SNAddressType(chain: request.networkType))

            let secretKey: Data

            switch request.cryptoType {
            case .sr25519:
                secretKey = keypair.privateKey().rawData()
            case .ed25519:
                let derivableSeedFactory = Ed25519KeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(seed.miniSeed,
                                                                               chaincodeList: chaincodes)
            case .ecdsa:
                let derivableSeedFactory = EcdsaKeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(seed.miniSeed,
                                                                               chaincodeList: chaincodes)
            }

            try self.keystore.saveSecretKey(secretKey, address: address)

            if !request.derivationPath.isEmpty {
                try self.keystore.saveDeriviation(request.derivationPath, address: address)
            }

            try self.keystore.saveSeed(seed, address: address)

            let settings = AccountSettings(visibleAssetIds: [], orderedAssetIds: [])

            return AccountItem(address: address,
                               cryptoType: request.cryptoType,
                               networkType: request.networkType.addressType(),
                               username: request.username,
                               publicKeyData: keypair.publicKey().rawData(),
                               settings:settings,
                               order: 0,
                               isSelected: true)
        }
    }

    func newAccountOperation(request: AccountImportKeystoreRequest) -> BaseOperation<AccountItem> {
        ClosureOperation {

            let keystoreExtractor = KeystoreExtractor()

            guard let data = request.keystore.data(using: .utf8) else {
                throw AccountOperationFactoryError.invalidKeystore
            }

            let keystoreDefinition = try JSONDecoder().decode(KeystoreDefinition.self,
                                                              from: data)

            guard let keystore = try? keystoreExtractor
                .extractFromDefinition(keystoreDefinition, password: request.password) else {
                throw AccountOperationFactoryError.decryption
            }

            let publicKey: IRPublicKeyProtocol

            switch request.cryptoType {
            case .sr25519:
                publicKey = try SNPublicKey(rawData: keystore.publicKeyData)
            case .ed25519:
                publicKey = try EDPublicKey(rawData: keystore.publicKeyData)
            case .ecdsa:
                publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
            }

            let addressFactory = SS58AddressFactory()
            let address = try addressFactory.address(fromAccountId: publicKey.rawData(),
                                                     type: SNAddressType(chain: request.networkType))

            try self.keystore.saveSecretKey(keystore.secretKeyData, address: address)

            let settings = AccountSettings(visibleAssetIds: [], orderedAssetIds: [])

            return AccountItem(address: address,
                               cryptoType: request.cryptoType,
                               networkType: request.networkType.addressType(),
                               username: request.username,
                               publicKeyData: keystore.publicKeyData,
                               settings: settings,
                               order: 0,
                               isSelected: true)
        }
    }

    private func createKeypairFactory(_ cryptoType: CryptoType) -> KeypairFactoryProtocol {
        switch cryptoType {
        case .sr25519:
            return SR25519KeypairFactory()
        case .ed25519:
            return Ed25519KeypairFactory()
        case .ecdsa:
            return EcdsaKeypairFactory()
        }
    }
}
