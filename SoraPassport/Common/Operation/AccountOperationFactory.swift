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
import SSFCrypto

protocol AccountOperationFactoryProtocol {
    func prepareAccountOperation(
        request: AccountCreationRequest,
        mnemonic: IRMnemonicProtocol
    ) -> BaseOperation<PreparedAccount>

    func prepareAccountOperation(
        request: AccountImportSeedRequest
    ) -> BaseOperation<PreparedAccount>

    func prepareAccountOperation(
        request: AccountImportKeystoreRequest
    ) -> BaseOperation<PreparedAccount>

    func persistPreparedAccount(_ prepared: PreparedAccount) throws
}

/// Secret material derived for an import stays in memory until duplicate and
/// lifecycle checks pass. Validation returns only `account` and never calls
/// `persist`, so typing/scanning a candidate cannot mutate Keychain.
final class PreparedAccount {
    let account: AccountItem
    private var suppliedOwnershipProof: Bool
    private var retainedOwnershipProof = false

    private let stateLock = NSLock()
    private var secretKey: Data
    private var entropy: Data?
    private var seed: Data?
    private var derivation: Data?
    private var isConsumed = false
    private let recoveryGate: WalletRecoveryCapabilityGate

    init(
        account: AccountItem,
        secretKey: Data,
        entropy: Data?,
        seed: Data?,
        derivationPath: String?,
        recoveryGate: WalletRecoveryCapabilityGate = .shared,
        suppliedOwnershipProof: Bool = false
    ) throws {
        try LegacySoraIdentityValidator.validate(
            address: account.address,
            publicKey: account.publicKeyData,
            cryptoType: account.cryptoType,
            networkType: account.networkType,
            derivationPath: derivationPath,
            entropy: entropy,
            rawSeed: seed,
            secret: secretKey,
            recoveryGate: recoveryGate
        )
        self.account = account
        self.suppliedOwnershipProof = suppliedOwnershipProof
        self.secretKey = secretKey
        self.entropy = entropy
        self.seed = seed
        self.recoveryGate = recoveryGate
        derivation = derivationPath?.data(using: .utf8)
    }

    /// Saves the account's secrets with add-only writes.
    ///
    /// iOS keeps Keychain items when the app is deleted, and older releases
    /// left items behind when an account was removed. When a tag for this
    /// address already exists, it is adopted only if it holds the same key
    /// (for sr25519 secrets: the same scalar, see
    /// `LegacySoraIdentityValidator.storedSecret`). Adopted items are never
    /// rewritten. If any existing item differs, nothing is written at all and
    /// `retainedKeyConflict` is thrown; the existing items stay as they are.
    func persist(to keystore: KeystoreProtocol) throws {
        stateLock.lock()
        guard !isConsumed else {
            stateLock.unlock()
            throw AccountCreateError.duplicated
        }
        do {
            let absent = try missingMaterialLocked(in: keystore)
            var written: [String] = []
            do {
                for (tag, value) in absent {
                    try keystore.addKey(value, with: tag)
                    written.append(tag)
                }
            } catch {
                // Each of these tags was proven absent under the lifecycle
                // lease, so removing only tags written by this failed attempt
                // cannot delete an installed or adopted item.
                for tag in written.reversed() {
                    try? keystore.deleteKey(for: tag)
                }
                throw error
            }
            isConsumed = true
            wipeLocked()
            stateLock.unlock()
        } catch {
            stateLock.unlock()
            throw error
        }
    }

    /// Called under the same lifecycle lease as persistence, before creating
    /// ownership metadata. A rejected import must leave no Keychain items.
    func validatePersistence(to keystore: KeystoreProtocol) throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isConsumed else { throw AccountCreateError.duplicated }
        _ = try missingMaterialLocked(in: keystore)
    }

    private func missingMaterialLocked(in keystore: KeystoreProtocol) throws -> [(String, Data)] {
        let secretTag = KeystoreTag.secretKeyTagForAddress(account.address)
        let derivationTag = KeystoreTag.deriviationTagForAddress(account.address)
        // The writes are separate Keychain calls, and the process can die
        // between any two. Their order makes every such state one that the
        // next start completes by itself:
        // - the path first: phrase or seed items written without it would
        //   derive another address;
        // - then the phrase and the seed, the items nothing else can derive,
        //   in the order of `UserStorageMigrator.restoreWriteOrder`: the
        //   first one written always proves the account by itself. That is
        //   the phrase when it has 12 to 24 words, and the seed when the
        //   phrase has 3, 6 or 9 words (a Google Drive backup made by App
        //   Store 3.8.6): such an entropy cannot be expanded again, so an
        //   account left with only that item would stay read-only, and a
        //   second import would be refused because an item exists. An
        //   account that has a proving item and no secret yet gets the
        //   missing seed and secret from the startup backfill
        //   (`LegacyGlobalEntropyScopedBackfill`);
        // - the secret last. Written first, a kill after it would leave an
        //   account that signs but never receives its phrase: the backfill
        //   skips an account that has a secret, and a second import of the
        //   same phrase is refused as a duplicate.
        var material: [(String, Data)] = []
        if let derivation {
            material.append((derivationTag, derivation))
        }
        for (value, tag, _) in UserStorageMigrator.restoreWriteOrder(
            address: account.address,
            entropy: entropy,
            rawSeed: seed,
            secret: secretKey
        ) {
            if let value {
                material.append((tag, value))
            }
        }
        // A JSON-only import already proves the derived secret, so a
        // retained path is unrelated auxiliary data and stays untouched.
        // Phrase/seed writes still require a compatible path.
        var existingSecret: Data? = try keystore.loadIfKeyExists(secretTag)
        defer { if let count = existingSecret?.count { existingSecret?.resetBytes(in: 0..<count) } }
        let adoptsWorkingSecret = existingSecret.map {
            LegacySoraIdentityValidator.storedSecret($0, matches: secretKey, cryptoType: account.cryptoType)
        } == true
        if adoptsWorkingSecret, material.contains(where: { $0.0 != secretTag }) {
            // Repair can fill gaps without overwriting older backup bytes.
            // If their retained path differs, only the secret is compatible.
            let retainedPath = try keystore.loadIfKeyExists(derivationTag)
            if retainedPath != nil && retainedPath != derivation {
                material = material.filter { $0.0 == secretTag }
            }
        } else if derivation == nil, entropy != nil || seed != nil,
                  let retainedPath = try keystore.loadIfKeyExists(derivationTag), !retainedPath.isEmpty {
            throw AccountCreateError.retainedKeyConflict
        }
        var absent: [(String, Data)] = []
        for (tag, value) in material {
            guard try keystore.checkKey(for: tag) else {
                absent.append((tag, value))
                continue
            }
            var retained = try keystore.fetchKey(for: tag)
            defer { retained.resetBytes(in: retained.startIndex ..< retained.endIndex) }
            let matches = tag == secretTag
                ? LegacySoraIdentityValidator.storedSecret(
                    retained, matches: value, cryptoType: account.cryptoType)
                : LegacySoraIdentityValidator.constantTimeEqual(retained, value)
            guard matches else {
                if adoptsWorkingSecret && tag != secretTag { continue }
                throw AccountCreateError.retainedKeyConflict
            }
        }
        return absent
    }

    func restrictToRetainedOwnership(_ grant: WalletOwnerPIN.RetainedAuthorization?) {
        suppliedOwnershipProof = false
        retainedOwnershipProof = grant?.addresses.contains(account.address) == true
    }

    func prepareInitialPINSetup(keystore: KeystoreProtocol, settings: SettingsManagerProtocol,
                               operationID: UUID) throws {
        guard suppliedOwnershipProof || retainedOwnershipProof else { return }
        try WalletOwnerPIN(keystore: keystore, settings: settings, recoveryGate: recoveryGate)
            .prepareInitialSetup(account: account, operationID: operationID)
    }

    /// Called by the journaled insert only. Factories prove material supplied
    /// for create/import; retained-wallet discovery deliberately has no grant.
    func prepareOwnershipBinding(keystore: KeystoreProtocol, settings: SettingsManagerProtocol,
                                 existingAccounts: [AccountItem]? = nil) throws {
        let ownerPIN = WalletOwnerPIN(keystore: keystore, settings: settings, recoveryGate: recoveryGate)
        let initialSetup: Bool
        if let existingAccounts {
            initialSetup = try existingAccounts.isEmpty || ownerPIN.requiresInitialSetup(accounts: existingAccounts)
        } else { initialSetup = try ownerPIN.requiresInitialSetup(accounts: [account]) }
        guard suppliedOwnershipProof, !initialSetup,
              var pin = try keystore.loadIfKeyExists(KeystoreTag.pincode.rawValue) else { return }
        defer { pin.resetBytes(in: 0..<pin.count) }
        guard let value = String(data: pin, encoding: .utf8) else { throw WalletOwnerPIN.Failure.invalidPIN }
        try WalletOwnerPIN(keystore: keystore, settings: settings, recoveryGate: recoveryGate)
            .prepareRebinding(address: account.address, to: value, consumeSetupIntent: true)
    }

    func discard() {
        stateLock.lock()
        wipeLocked()
        isConsumed = true
        stateLock.unlock()
    }

    deinit {
        stateLock.lock()
        wipeLocked()
        stateLock.unlock()
    }

    private func wipeLocked() {
        secretKey.resetBytes(
            in: secretKey.startIndex ..< secretKey.endIndex
        )
        if let entropyCount = entropy?.count {
            entropy?.resetBytes(in: 0 ..< entropyCount)
        }
        if let seedCount = seed?.count {
            seed?.resetBytes(in: 0 ..< seedCount)
        }
        if let derivationCount = derivation?.count {
            derivation?.resetBytes(in: 0 ..< derivationCount)
        }
        entropy = nil
        seed = nil
        derivation = nil
    }
}

final class AccountOperationFactory: AccountOperationFactoryProtocol {
    private(set) var keystore: KeystoreProtocol
    private let recoveryGate: WalletRecoveryCapabilityGate

    init(
        keystore: KeystoreProtocol,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) {
        self.keystore = keystore
        self.recoveryGate = recoveryGate
    }

    func prepareAccountOperation(
        request: AccountCreationRequest,
        mnemonic: IRMnemonicProtocol
    ) -> BaseOperation<PreparedAccount> {
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

            let settings = AccountSettings(visibleAssetIds: [], orderedAssetIds: [])

            let account = AccountItem(
                address: address,
                cryptoType: request.cryptoType,
                networkType: SNAddressType(chain: request.type),
                username: request.username,
                publicKeyData: keypair.publicKey().rawData(),
                settings: settings,
                order: 0,
                isSelected: true
            )
            return try PreparedAccount(
                account: account,
                secretKey: secretKey,
                entropy: result.mnemonic.entropy(),
                seed: result.seed.miniSeed,
                derivationPath: request.derivationPath.isEmpty
                    ? nil
                    : request.derivationPath,
                recoveryGate: self.recoveryGate,
                suppliedOwnershipProof: true
            )
        }
    }

    func prepareAccountOperation(
        request: AccountImportSeedRequest
    ) -> BaseOperation<PreparedAccount> {
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

            let settings = AccountSettings(visibleAssetIds: [], orderedAssetIds: [])

            let account = AccountItem(
                address: address,
                cryptoType: request.cryptoType,
                networkType: request.networkType.addressType(),
                username: request.username,
                publicKeyData: keypair.publicKey().rawData(),
                settings: settings,
                order: 0,
                isSelected: true
            )
            return try PreparedAccount(
                account: account,
                secretKey: secretKey,
                entropy: nil,
                seed: seed,
                derivationPath: request.derivationPath.isEmpty
                    ? nil
                    : request.derivationPath,
                recoveryGate: self.recoveryGate,
                suppliedOwnershipProof: true
            )
        }
    }

    func prepareAccountOperation(
        request: AccountImportKeystoreRequest
    ) -> BaseOperation<PreparedAccount> {
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

            let settings = AccountSettings(visibleAssetIds: [], orderedAssetIds: [])

            let account = AccountItem(
                address: address,
                cryptoType: request.cryptoType,
                networkType: request.networkType.addressType(),
                username: request.username,
                publicKeyData: keystore.publicKeyData,
                settings: settings,
                order: 0,
                isSelected: true
            )
            return try PreparedAccount(
                account: account,
                secretKey: keystore.secretKeyData,
                entropy: nil,
                seed: nil,
                derivationPath: nil,
                recoveryGate: self.recoveryGate,
                suppliedOwnershipProof: true
            )
        }
    }

    func persistPreparedAccount(_ prepared: PreparedAccount) throws {
        // The lifecycle lease was recovery-gated before preparation. Recheck
        // the sticky marker immediately before the first Keychain write.
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        try prepared.persist(to: keystore)
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
