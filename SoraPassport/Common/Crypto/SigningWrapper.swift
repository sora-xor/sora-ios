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
import SoraKeystore
import SSFCrypto
import SSFUtils

enum SigningWrapperError: Error {
    case missingSelectedAccount
    case missingSecretKey
    case missingNetworkSnapshot
    case identityMismatch
    case signatureVerificationFailed
    case retainedWalletRecoveryRequired
}

/// Resolves legacy SORA2 signing material without writing or normalizing the
/// Keychain. This keeps raw-seed-only and entropy-only installations usable
/// while preserving their existing source records byte-for-byte.
enum LegacySoraSecretResolver {
    static func resolve(
        account: AccountItem,
        keystore: KeystoreProtocol
    ) throws -> Data? {
        var directSecret = try keystore.fetchSecretKeyForAddress(
            account.address
        )
        defer { wipeSensitive(&directSecret) }
        if let secret = directSecret {
            guard !secret.isEmpty else {
                throw SigningWrapperError.missingSecretKey
            }
            return secret
        }

        let derivationPath =
            try keystore.fetchDeriviationForAddress(account.address) ?? ""
        let junction = derivationPath.isEmpty
            ? nil
            : try SubstrateJunctionFactory().parse(path: derivationPath)
        let chaincodes = junction?.chaincodes ?? []

        var entropy = try keystore.fetchEntropyForAddress(account.address)
        defer { wipeSensitive(&entropy) }
        var sourceSeed: Data?
        defer { wipeSensitive(&sourceSeed) }
        if let entropy {
            let mnemonic = try IRMnemonicCreator(language: .english)
                .mnemonic(fromEntropy: entropy)
            var phrase = mnemonic.toString()
            defer { phrase.removeAll(keepingCapacity: false) }
            sourceSeed = try SeedFactory().deriveSeed(
                from: phrase,
                password: junction?.password ?? ""
            ).seed.miniSeed
        } else {
            sourceSeed = try keystore.fetchSeedForAddress(account.address)
        }

        guard let sourceSeed, !sourceSeed.isEmpty else {
            return nil
        }
        let factory = keypairFactory(for: account.cryptoType)
        let keypair = try factory.createKeypairFromSeed(
            sourceSeed,
            chaincodeList: chaincodes
        )
        let publicKey = keypair.publicKey().rawData()
        let address = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: account.networkType
        )
        guard
            publicKey == account.publicKeyData,
            address == account.address
        else {
            throw SigningWrapperError.identityMismatch
        }

        switch account.cryptoType {
        case .sr25519:
            return keypair.privateKey().rawData()
        case .ed25519:
            return try Ed25519KeypairFactory().deriveChildSeedFromParent(
                sourceSeed.miniSeed,
                chaincodeList: chaincodes
            )
        case .ecdsa:
            return try EcdsaKeypairFactory().deriveChildSeedFromParent(
                sourceSeed.miniSeed,
                chaincodeList: chaincodes
            )
        }
    }

    private static func wipeSensitive(_ value: inout Data?) {
        if let count = value?.count {
            value?.resetBytes(in: 0 ..< count)
        }
        value = nil
    }

    private static func keypairFactory(
        for cryptoType: CryptoType
    ) -> KeypairFactoryProtocol {
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

enum Sora2SignatureVerifier {
    static func verify(
        signature: IRSignatureProtocol,
        originalData: Data,
        secretKey: Data,
        account: AccountItem
    ) throws {
        let verified: Bool
        switch account.cryptoType {
        case .sr25519:
            guard let signature = signature as? SNSignature else {
                throw SigningWrapperError.signatureVerificationFailed
            }
            let publicKey = try SNPublicKey(rawData: account.publicKeyData)
            verified = SNSignatureVerifier().verify(
                signature,
                forOriginalData: originalData,
                using: publicKey
            )
        case .ed25519:
            let keypair = try Ed25519KeypairFactory().createKeypairFromSeed(
                secretKey.miniSeed,
                chaincodeList: []
            )
            guard keypair.publicKey().rawData() == account.publicKeyData else {
                throw SigningWrapperError.identityMismatch
            }
            verified = EDSignatureVerifier().verify(
                signature,
                forOriginalData: originalData,
                usingPublicKey: keypair.publicKey()
            )
        case .ecdsa:
            let keypair = try EcdsaKeypairFactory().createKeypairFromSeed(
                secretKey.miniSeed,
                chaincodeList: []
            )
            guard keypair.publicKey().rawData() == account.publicKeyData else {
                throw SigningWrapperError.identityMismatch
            }
            verified = SECSignatureVerifier().verify(
                signature,
                forOriginalData: try originalData.blake2b32(),
                usingPublicKey: keypair.publicKey()
            )
        }
        guard verified else {
            throw SigningWrapperError.signatureVerificationFailed
        }
    }
}

final class SigningWrapper: LifecycleSigningWrapperProtocol {
    let keystore: KeystoreProtocol
    let account: AccountItem
    var signingAccount: AccountItem { account }
    private let recoverySettings: SettingsManagerProtocol?

    init(
        keystore: KeystoreProtocol,
        account: AccountItem,
        recoverySettings: SettingsManagerProtocol? = SettingsManager.shared
    ) {
        self.keystore = keystore
        self.account = account
        self.recoverySettings = recoverySettings
    }

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        guard
            let lifecycleLease =
                try WalletLifecycleCoordinator.shared
                    .tryAcquireForMutableWalletAccess()
        else {
            // A caller already inside a lifecycle transaction must use the
            // lease-aware overload. Failing closed here avoids recursive
            // acquisition deadlocks and signing across account mutation.
            throw WalletNetworkMigrationError.lifecycleMutationBusy
        }
        defer { lifecycleLease.release() }
        return try sign(
            originalData,
            lifecycleLease: lifecycleLease
        )
    }

    func sign(
        _ originalData: Data,
        lifecycleLease: WalletLifecycleLease
    ) throws -> IRSignatureProtocol {
        try WalletLifecycleCoordinator.shared.withExclusiveAccess(
            using: lifecycleLease
        ) {
            try signLocked(originalData)
        }
    }

    private func signLocked(
        _ originalData: Data
    ) throws -> IRSignatureProtocol {
        if let recoverySettings,
           SelectedWalletSettings.transactionSigningAvailability(
               settings: recoverySettings,
               keystore: keystore,
               account: account
           ) == .recoveryRequired {
            throw SigningWrapperError.retainedWalletRecoveryRequired
        }

        // Recheck the full recovery capability boundary immediately before
        // touching encrypted signing material. This also covers callers that
        // supply an existing lease through background transaction routes.
        try WalletRecoveryCapabilityGate.shared
            .requireMutableWalletAccess()
        try validateSelectedSora2Identity()
        guard var secretKey = try LegacySoraSecretResolver.resolve(
            account: account,
            keystore: keystore
        ) else {
            throw SigningWrapperError.missingSecretKey
        }
        defer {
            secretKey.resetBytes(
                in: secretKey.startIndex ..< secretKey.endIndex
            )
        }

        let signature: IRSignatureProtocol
        switch account.cryptoType {
        case .sr25519:
            signature = try signSr25519(
                originalData,
                secretKeyData: secretKey,
                publicKeyData: account.publicKeyData
            )
        case .ed25519:
            signature = try signEd25519(
                originalData,
                secretKey: secretKey
            )
        case .ecdsa:
            signature = try signEcdsa(
                originalData,
                secretKey: secretKey
            )
        }
        try Sora2SignatureVerifier.verify(
            signature: signature,
            originalData: originalData,
            secretKey: secretKey,
            account: account
        )
        return signature
    }

    private func validateSelectedSora2Identity() throws {
        guard
            let selected = SelectedWalletSettings.shared.currentAccount,
            selected.isSelected,
            selected.address == account.address,
            selected.publicKeyData == account.publicKeyData,
            selected.cryptoType == account.cryptoType,
            selected.networkType == account.networkType
        else {
            throw SigningWrapperError.missingSelectedAccount
        }

        guard
            let snapshot = try WalletNetworkStore().load(),
            snapshot.schemaVersion ==
                WalletNetworkSnapshot.currentSchemaVersion,
            snapshot.selectedWalletId == account.address,
            snapshot.wallets.contains(where: {
                $0.id == account.address &&
                    $0.existingSoraAddress == account.address
            }),
            snapshot.accounts.contains(where: {
                $0.walletId == account.address &&
                    $0.networkId == .sora2 &&
                    $0.derivationVersion == 0 &&
                    $0.publicKey == account.publicKeyData &&
                    $0.address == account.address
            })
        else {
            throw SigningWrapperError.missingNetworkSnapshot
        }

        var secret = try keystore.fetchSecretKeyForAddress(account.address)
        var entropy = try keystore.fetchEntropyForAddress(account.address)
        var rawSeed = try keystore.fetchSeedForAddress(account.address)
        defer {
            if let count = secret?.count {
                secret?.resetBytes(in: 0 ..< count)
            }
            if let count = entropy?.count {
                entropy?.resetBytes(in: 0 ..< count)
            }
            if let count = rawSeed?.count {
                rawSeed?.resetBytes(in: 0 ..< count)
            }
            secret = nil
            entropy = nil
            rawSeed = nil
        }
        try LegacySoraIdentityValidator.validate(
            address: account.address,
            publicKey: account.publicKeyData,
            cryptoType: account.cryptoType,
            networkType: account.networkType,
            derivationPath:
                try keystore.fetchDeriviationForAddress(account.address),
            entropy: entropy,
            rawSeed: rawSeed,
            secret: secret,
            recoveryGate: .shared
        )
        guard
            secret != nil ||
                entropy != nil ||
                rawSeed != nil
        else {
            throw SigningWrapperError.missingSecretKey
        }
    }
}
