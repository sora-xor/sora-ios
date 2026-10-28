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
    /// No key for the account is on this device (for example a new
    /// iPhone). The account is read-only here. Nothing was signed and no
    /// Keychain item was changed. Importing the account's phrase or Google
    /// Drive backup restores its keys in place.
    case keysNotOnThisDevice
    /// Keys for the account are on this device but do not prove it. They are
    /// left untouched; the account is read-only here. Nothing was signed.
    case keysNotVerified
}

extension SigningWrapperError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .keysNotOnThisDevice:
            return WalletUX.text(
                "This account's keys are not on this iPhone, so it can't send. Your funds are not affected. To send from it, import this account again with its recovery phrase or Google Drive backup."
            )
        case .keysNotVerified:
            return WalletUX.text(
                "The keys saved for this account on this iPhone could not be verified, so it can't send. They have not been changed, and your funds are not affected. Contact SORA support."
            )
        default:
            return nil
        }
    }
}

/// Resolves legacy SORA2 signing material without writing or normalizing the
/// Keychain. This keeps raw-seed-only and entropy-only installations usable
/// while preserving their existing source records byte-for-byte.
enum LegacySoraSecretResolver {
    static func resolve(
        account: AccountItem,
        keystore: KeystoreProtocol,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws -> Data? {
        try recoveryGate.requireAuthorizedLifecycleContinuation()
        var directSecret = try keystore.fetchSecretKeyForAddress(
            account.address
        )
        defer { wipeSensitive(&directSecret) }
        if let secret = directSecret {
            try LegacySoraIdentityValidator.validateSigningSecret(
                address: account.address, publicKey: account.publicKeyData,
                cryptoType: account.cryptoType, networkType: account.networkType,
                secret: secret, recoveryGate: recoveryGate)
            return secret
        }

        var backup = try WalletBackupMaterial.load(for: account, keystore: keystore, recoveryGate: recoveryGate)
        defer { backup.wipe() }
        let path = backup.derivationPath ?? ""
        let junction = path.isEmpty ? nil : try SubstrateJunctionFactory().parse(path: path)
        let chaincodes = junction?.chaincodes ?? []
        var sourceSeed = backup.seed
        defer { wipeSensitive(&sourceSeed) }
        if sourceSeed == nil, let entropy = backup.entropy {
            var phrase = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy).toString()
            defer { phrase.removeAll(keepingCapacity: false) }
            sourceSeed = try SeedFactory().deriveSeed(from: phrase, password: junction?.password ?? "").seed.miniSeed
        }
        guard let sourceSeed else {
            if let error = backup.firstReadError { throw error }
            if backup.phraseStatus != .absent || backup.seedStatus != .absent {
                throw SigningWrapperError.identityMismatch
            }
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
        guard LegacySoraIdentityValidator.hasValidSecretLength(secretKey, cryptoType: account.cryptoType),
              account.publicKeyData.count == (account.cryptoType == .ecdsa ? 33 : 32) else {
            throw SigningWrapperError.keysNotVerified
        }
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
    private let lifecycleCoordinator: WalletLifecycleCoordinator
    private let recoveryGate: WalletRecoveryCapabilityGate
    private let selectedAccount: () -> AccountItem?
    private let networkSnapshot: () throws -> WalletNetworkSnapshot?
    private let isWatchOnly: (String) -> Bool
    var signingAccount: AccountItem { account }

    init(keystore: KeystoreProtocol, account: AccountItem,
         lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
         recoveryGate: WalletRecoveryCapabilityGate = .shared,
         selectedAccount: @escaping () -> AccountItem? = { SelectedWalletSettings.shared.currentAccount },
         networkSnapshot: @escaping () throws -> WalletNetworkSnapshot? = { try WalletNetworkStore().load() },
         isWatchOnly: @escaping (String) -> Bool = { SettingsManager.shared.bool(for: "wallet.watchOnly.\($0)") == true }) {
        self.lifecycleCoordinator = lifecycleCoordinator
        self.recoveryGate = recoveryGate
        self.selectedAccount = selectedAccount
        self.networkSnapshot = networkSnapshot
        self.isWatchOnly = isWatchOnly
        self.keystore = keystore
        self.account = account
    }

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        guard
            let lifecycleLease =
                try lifecycleCoordinator
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
        try lifecycleCoordinator.withExclusiveAccess(
            using: lifecycleLease
        ) {
            try signLocked(originalData)
        }
    }

    private func signLocked(
        _ originalData: Data
    ) throws -> IRSignatureProtocol {
        // Recheck the full recovery capability boundary immediately before
        // touching encrypted signing material. This also covers callers that
        // supply an existing lease through background transaction routes.
        try recoveryGate
            .requireMutableWalletAccess()
        try validateSelectedSora2Identity()
        let resolved: Data?
        do {
            resolved = try LegacySoraSecretResolver.resolve(
                account: account,
                keystore: keystore, recoveryGate: recoveryGate
            )
        } catch SigningWrapperError.identityMismatch {
            throw SigningWrapperError.keysNotVerified
        }
        guard var secretKey = resolved else {
            throw SigningWrapperError.keysNotOnThisDevice
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
            let selected = selectedAccount(),
            selected.isSelected,
            selected.address == account.address,
            selected.publicKeyData == account.publicKeyData,
            selected.cryptoType == account.cryptoType,
            selected.networkType == account.networkType
        else {
            throw SigningWrapperError.missingSelectedAccount
        }

        let snapshot = try networkSnapshot()
        guard !isWatchOnly(account.address),
              snapshot?.wallets.first(where: { $0.id == account.address })?.secretSource != .watchOnly else {
            throw SigningWrapperError.keysNotVerified
        }
        if snapshot?.wallets.first(where: { $0.id == account.address })?
            .secretSource == .signingUnavailable {
            // Read-only on this device. Read no secret.
            throw try keystore.hasScopedSigningMaterial(for: account.address)
                ? SigningWrapperError.keysNotVerified
                : SigningWrapperError.keysNotOnThisDevice
        }
        guard
            let snapshot,
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

        do {
            guard var secret = try LegacySoraSecretResolver.resolve(account: account, keystore: keystore, recoveryGate: recoveryGate) else {
                throw SigningWrapperError.keysNotOnThisDevice
            }
            defer { secret.resetBytes(in: secret.startIndex ..< secret.endIndex) }
            try LegacySoraIdentityValidator.validateSigningSecret(
                address: account.address, publicKey: account.publicKeyData,
                cryptoType: account.cryptoType, networkType: account.networkType,
                secret: secret, recoveryGate: recoveryGate)
        } catch SigningWrapperError.keysNotOnThisDevice {
            throw SigningWrapperError.keysNotOnThisDevice
        } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
            throw SigningWrapperError.keysNotVerified
        }
    }
}
