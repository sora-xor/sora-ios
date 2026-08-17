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
import RobinHood
import SoraKeystore
import IrohaCrypto
import SSFUtils
import SSFCrypto

protocol SelectedWalletSettingsProtocol: AnyObject {
    var currentAccount: AccountItem? { get }
    func performSave(
        value: AccountItem,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    )
    func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void)
    func save(value: AccountItem)
}

final class SelectedWalletSettings: PersistentValueSettings<AccountItem>, SelectedWalletSettingsProtocol {
    struct RetainedAccountRepairPlan: Equatable {
        let account: AccountItem
    }

    private struct RetainedSigningMaterial {
        let secretKey: Data
        let seed: Data?
        let entropy: Data?
        let source: String
    }

    private enum RetainedAccountRepairKey {
        static let recoveryRequired = "walletMigrationRecoveryRequired"
        static let recoveryAccount = "walletMigrationRecoveryExpectedAccount"
    }

    static let shared = SelectedWalletSettings(
        storageFacade: UserDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue
    )

    let operationQueue: OperationQueue

    init(storageFacade: StorageFacadeProtocol, operationQueue: OperationQueue) {
        self.operationQueue = operationQueue

        super.init(storageFacade: storageFacade)
    }

    override func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void) {
        let mapper = AccountItemMapper()

        let repository = storageFacade.createRepository(
            filter: NSPredicate.selectedAccount(),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let operation = repository.fetchAllOperation(with: options)

        operation.completionBlock = {
            do {
                let result = try operation.extractNoCancellableResultData().first
                guard result == nil else {
                    completionClosure(.success(result))
                    return
                }

                guard let repairPlan = try Self.retainedAccountRepairPlan(
                    settings: SettingsManager.shared,
                    keystore: Keychain()
                ) else {
                    completionClosure(.success(nil))
                    return
                }

                self.performSave(value: repairPlan.account) { saveResult in
                    switch saveResult {
                    case let .success(account):
                        completionClosure(.success(account))
                    case let .failure(error):
                        completionClosure(.failure(error))
                    }
                }
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperation(operation)
    }

    override func performSave(
        value: AccountItem,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    ) {
        let mapper = ManagedAccountItemMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let maybeCurrentAccountOperation = internalValue.map {
            repository.fetchOperation(by: $0.identifier, options: options)
        }

        let newAccountOperation = repository.fetchOperation(by: value.identifier, options: options)

        let saveOperation = repository.saveOperation({
            var accountsToSave: [ManagedAccountItem] = []

            if let currentAccount = try maybeCurrentAccountOperation?.extractNoCancellableResultData() {
                accountsToSave.append(
                    ManagedAccountItem(address: currentAccount.address,
                                       cryptoType: currentAccount.cryptoType,
                                       networkType: currentAccount.networkType,
                                       username: currentAccount.username,
                                       publicKeyData: currentAccount.publicKeyData,
                                       order: currentAccount.order,
                                       settings: currentAccount.settings,
                                       isSelected: false)
                )
            }

            if let newAccount = try newAccountOperation.extractNoCancellableResultData() {
                accountsToSave.append(
                    ManagedAccountItem(
                        address: value.address,
                        cryptoType: value.cryptoType,
                        networkType: value.networkType,
                        username: value.username,
                        publicKeyData: value.publicKeyData,
                        order: newAccount.order,
                        settings: value.settings,
                        isSelected: true
                    )
                )
            } else {
                accountsToSave.append(
                    ManagedAccountItem(
                        address: value.address,
                        cryptoType: value.cryptoType,
                        networkType: value.networkType,
                        username: value.username,
                        publicKeyData: value.publicKeyData,
                        order: value.order,
                        settings: value.settings,
                        isSelected: true
                    )
                )
            }

            return accountsToSave
        }, { [] })

        var dependencies: [Operation] = [newAccountOperation]

        if let currentAccountOperation = maybeCurrentAccountOperation {
            dependencies.append(currentAccountOperation)
        }

        dependencies.forEach { saveOperation.addDependency($0) }

        saveOperation.completionBlock = { [weak self] in
            do {
                _ = try saveOperation.extractNoCancellableResultData()
                self?.internalValue = value
                completionClosure(.success(value))
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperations(dependencies + [saveOperation], waitUntilFinished: false)
    }
}

extension SelectedWalletSettings {
    static func retainedAccountRepairPlan(
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol
    ) throws -> RetainedAccountRepairPlan? {
        guard
            settings.bool(for: RetainedAccountRepairKey.recoveryRequired) == true,
            let retainedAccount = retainedRecoveryAccount(settings: settings)
        else {
            return nil
        }

        let derivedAddress = try SS58AddressFactory().address(
            fromAccountId: retainedAccount.publicKeyData,
            type: retainedAccount.networkType
        )
        guard derivedAddress == retainedAccount.address else {
            return nil
        }

        let account = AccountItem(
            address: retainedAccount.address,
            cryptoType: retainedAccount.cryptoType,
            networkType: retainedAccount.networkType,
            username: retainedAccount.username,
            publicKeyData: retainedAccount.publicKeyData,
            settings: retainedAccount.settings,
            order: retainedAccount.order,
            isSelected: true
        )

        // Keep recovery state intact until the public account row is durably saved.
        // Root's inconsistent-state migrator performs the verified signing repair next.
        return RetainedAccountRepairPlan(account: account)
    }

    static func requiresRecoveryReadOnlyMode(
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol,
        account: AccountItem
    ) -> Bool {
        guard matchesRetainedRecoveryIdentity(settings: settings, account: account) else {
            return false
        }

        if (try? repairRetainedSigningMaterialIfPossible(
            settings: settings,
            keystore: keystore,
            account: account
        )) == true {
            return false
        }

        if hasAnyRetainedSigningMaterial(keystore: keystore, account: account) {
            return true
        }

        // There is nothing the full-screen restore prompt can consume automatically.
        // Preserve the recovery marker and keep signing fail-closed, but allow users to
        // browse balances, prices, activity, and receive funds without being trapped.
        Logger.shared.warning(
            "SORA wallet signing material is unavailable; continuing in browse-only mode"
        )
        return false
    }

    private static func hasAnyRetainedSigningMaterial(
        keystore: KeystoreProtocol,
        account: AccountItem
    ) -> Bool {
        let identifiers = [
            KeystoreTag.secretKeyTagForAddress(account.address),
            KeystoreTag.seedTagForAddress(account.address),
            KeystoreTag.entropyTagForAddress(account.address),
            KeystoreTag.legacyEntropy.rawValue,
            "privateKey",
            "ethKey"
        ]

        return identifiers.contains { (try? keystore.checkKey(for: $0)) == true }
    }

    static func repairRetainedSigningMaterialIfPossible(
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol,
        account: AccountItem
    ) throws -> Bool {
        guard matchesRetainedRecoveryIdentity(settings: settings, account: account) else {
            logAutomaticRecoveryBlocked(reason: "retained-identity-mismatch")
            return false
        }

        // Never pass an arbitrary retained secret into the native sr25519 signer. Some
        // malformed 64-byte encodings can panic below Swift's throwable boundary. A
        // retained secret is accepted only when independently derived seed/entropy first
        // proves the exact public key and address, and the bytes agree with that result.
        let existingSecret = try keystore.fetchSecretKeyForAddress(account.address)
        let derivationPath = try keystore.fetchDeriviationForAddress(account.address) ?? ""
        let scopedSeed = try keystore.fetchSeedForAddress(account.address)
        let scopedEntropy = try keystore.fetchEntropyForAddress(account.address)
        let candidates: [RetainedSigningMaterial]

        if scopedSeed != nil || scopedEntropy != nil {
            guard let scopedMaterial = try retainedScopedSigningMaterial(
                seed: scopedSeed,
                entropy: scopedEntropy,
                derivationPath: derivationPath,
                account: account
            ) else {
                // Contradictory or invalid address-scoped records must never fall through
                // to a different legacy source.
                logAutomaticRecoveryBlocked(reason: "scoped-material-invalid-or-conflicting")
                return false
            }

            candidates = [scopedMaterial]
        } else if
            derivationPath.isEmpty,
            account.cryptoType == .sr25519,
            account.networkType == ApplicationConfig.shared.addressType
        {
            if let legacyEntropy = try keystore.loadIfKeyExists(
                KeystoreTag.legacyEntropy.rawValue
            ) {
                if let legacyMaterial = try retainedSigningMaterial(
                    legacyEntropy: legacyEntropy,
                    account: account
                ) {
                    candidates = [legacyMaterial]
                } else {
                    candidates = try retainedLegacySecretCandidates(
                        keystore: keystore,
                        account: account
                    )
                    if candidates.isEmpty {
                        logAutomaticRecoveryBlocked(
                            reason: "legacy-entropy-identity-mismatch"
                        )
                    }
                }
            } else {
                candidates = try retainedLegacySecretCandidates(
                    keystore: keystore,
                    account: account
                )
                if candidates.isEmpty {
                    logAutomaticRecoveryBlocked(reason: "no-compatible-retained-secret")
                }
            }
        } else {
            logAutomaticRecoveryBlocked(reason: "legacy-source-shape-unsupported")
            candidates = []
        }

        for material in candidates {
            if let existingSecret, existingSecret != material.secretKey {
                continue
            }

            if existingSecret == nil {
                try keystore.saveSecretKey(material.secretKey, address: account.address)
            }

            guard hasVerifiedSigningKey(keystore: keystore, account: account) else {
                if existingSecret == nil {
                    try? keystore.deleteKeyIfExists(
                        for: KeystoreTag.secretKeyTagForAddress(account.address)
                    )
                }
                continue
            }

            if let seed = material.seed {
                try? keystore.saveSeed(seed, address: account.address)
            }
            if let entropy = material.entropy {
                try? keystore.saveEntropy(entropy, address: account.address)
            }

            clearRetainedRecoveryState(settings: settings)
            Logger.shared.info(
                "SORA retained wallet signing material repaired automatically: \(material.source)"
            )
            return true
        }

        if existingSecret != nil {
            logAutomaticRecoveryBlocked(reason: "existing-secret-has-no-verified-source")
        }

        return false
    }

    private static func retainedLegacySecretCandidates(
        keystore: KeystoreProtocol,
        account: AccountItem
    ) throws -> [RetainedSigningMaterial] {
        let identifiers = ["privateKey", "ethKey"]

        return try identifiers.flatMap { identifier -> [RetainedSigningMaterial] in
            guard let secret = try keystore.loadIfKeyExists(identifier) else {
                return []
            }

            var candidates: [RetainedSigningMaterial] = []
            let seedMaterial: RetainedSigningMaterial?

            do {
                seedMaterial = try retainedSigningMaterial(
                    seed: secret,
                    entropy: nil,
                    derivationPath: "",
                    source: "legacy-\(identifier)-as-seed",
                    account: account
                )
            } catch {
                seedMaterial = nil
            }

            if let seedMaterial {
                candidates.append(seedMaterial)
            }

            return candidates
        }
    }

    private static func logAutomaticRecoveryBlocked(reason: String) {
        Logger.shared.warning("SORA automatic retained-wallet recovery blocked: \(reason)")
    }

    private static func retainedScopedSigningMaterial(
        seed: Data?,
        entropy: Data?,
        derivationPath: String,
        account: AccountItem
    ) throws -> RetainedSigningMaterial? {
        let seedMaterial = try seed.flatMap {
            try retainedSigningMaterial(
                seed: $0,
                entropy: entropy,
                derivationPath: derivationPath,
                source: entropy == nil ? "address-seed" : "address-seed-and-entropy",
                account: account
            )
        }
        let entropyMaterial = try entropy.flatMap {
            try retainedSigningMaterial(
                entropy: $0,
                derivationPath: derivationPath,
                source: seed == nil ? "address-entropy" : "address-seed-and-entropy",
                account: account
            )
        }

        if seed != nil, entropy != nil {
            guard
                let seedMaterial,
                let entropyMaterial,
                seedMaterial.seed == entropyMaterial.seed
            else {
                return nil
            }

            return seedMaterial
        }

        return seedMaterial ?? entropyMaterial
    }

    private static func retainedSigningMaterial(
        legacyEntropy: Data,
        account: AccountItem
    ) throws -> RetainedSigningMaterial? {
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(
            fromEntropy: legacyEntropy
        )
        guard [12, 15, 24].contains(mnemonic.allWords().count) else {
            return nil
        }

        let seed = try SeedFactory().deriveSeed(
            from: mnemonic.toString(),
            password: ""
        ).seed.miniSeed

        return try retainedSigningMaterial(
            seed: seed,
            entropy: legacyEntropy,
            derivationPath: "",
            source: "legacy-entropy",
            account: account
        )
    }

    private static func matchesRetainedRecoveryIdentity(
        settings: SettingsManagerProtocol,
        account: AccountItem
    ) -> Bool {
        guard
            settings.bool(for: RetainedAccountRepairKey.recoveryRequired) == true,
            let retainedAccount = retainedRecoveryAccount(settings: settings),
            retainedAccount.address == account.address,
            retainedAccount.publicKeyData == account.publicKeyData,
            retainedAccount.networkType == account.networkType,
            retainedAccount.cryptoType == account.cryptoType,
            let derivedAddress = try? SS58AddressFactory().address(
                fromAccountId: account.publicKeyData,
                type: account.networkType
            )
        else {
            return false
        }

        return derivedAddress == account.address
    }

    static func isRetainedRecoveryAccount(
        settings: SettingsManagerProtocol,
        account: AccountItem
    ) -> Bool {
        matchesRetainedRecoveryIdentity(settings: settings, account: account)
    }

    @discardableResult
    static func completeRetainedRecoveryAfterVerifiedImport(
        settings: SettingsManagerProtocol,
        account: AccountItem
    ) -> Bool {
        guard matchesRetainedRecoveryIdentity(settings: settings, account: account) else {
            return false
        }

        clearRetainedRecoveryState(settings: settings)
        return true
    }

    private static func retainedSigningMaterial(
        entropy: Data,
        derivationPath: String,
        source: String,
        account: AccountItem
    ) throws -> RetainedSigningMaterial? {
        let password: String

        if derivationPath.isEmpty {
            password = ""
        } else {
            password = try SubstrateJunctionFactory().parse(path: derivationPath).password ?? ""
        }

        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy)
        let seed = try SeedFactory().deriveSeed(
            from: mnemonic.toString(),
            password: password
        ).seed.miniSeed

        return try retainedSigningMaterial(
            seed: seed,
            entropy: entropy,
            derivationPath: derivationPath,
            source: source,
            account: account
        )
    }

    private static func retainedSigningMaterial(
        seed: Data,
        entropy: Data?,
        derivationPath: String,
        source: String,
        account: AccountItem
    ) throws -> RetainedSigningMaterial? {
        let chaincodes: [Chaincode] = derivationPath.isEmpty
            ? []
            : try SubstrateJunctionFactory().parse(path: derivationPath).chaincodes
        let miniSeed = seed.miniSeed
        let keypair: IRCryptoKeypairProtocol
        let secretKey: Data

        switch account.cryptoType {
        case .sr25519:
            keypair = try SR25519KeypairFactory().createKeypairFromSeed(
                seed,
                chaincodeList: chaincodes
            )
            secretKey = keypair.privateKey().rawData()
        case .ed25519:
            let factory = Ed25519KeypairFactory()
            keypair = try factory.createKeypairFromSeed(seed, chaincodeList: chaincodes)
            secretKey = try factory.deriveChildSeedFromParent(
                miniSeed,
                chaincodeList: chaincodes
            )
        case .ecdsa:
            let factory = EcdsaKeypairFactory()
            keypair = try factory.createKeypairFromSeed(seed, chaincodeList: chaincodes)
            secretKey = try factory.deriveChildSeedFromParent(
                miniSeed,
                chaincodeList: chaincodes
            )
        }

        let publicKey = keypair.publicKey().rawData()
        guard publicKey == account.publicKeyData else {
            return nil
        }

        let address = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: account.networkType
        )
        guard address == account.address else {
            return nil
        }

        return RetainedSigningMaterial(
            secretKey: secretKey,
            seed: seed,
            entropy: entropy,
            source: source
        )
    }

    private static func clearRetainedRecoveryState(settings: SettingsManagerProtocol) {
        settings.removeValue(for: RetainedAccountRepairKey.recoveryRequired)
        settings.removeValue(for: "walletMigrationRecoveryReason")
        settings.removeValue(for: RetainedAccountRepairKey.recoveryAccount)
    }

    private static func retainedRecoveryAccount(
        settings: SettingsManagerProtocol
    ) -> AccountItem? {
        if let account = settings.value(
            of: AccountItem.self,
            for: RetainedAccountRepairKey.recoveryAccount
        ) {
            return account
        }

        guard let account = settings.value(
            of: AccountItem.self,
            for: SettingsKey.selectedAccount.rawValue
        ) else {
            return nil
        }

        settings.set(value: account, for: RetainedAccountRepairKey.recoveryAccount)
        return account
    }

    static func hasVerifiedSigningKey(
        keystore: KeystoreProtocol,
        account: AccountItem
    ) -> Bool {
        do {
            guard try keystore.checkSecretKeyForAddress(account.address) else {
                return false
            }

            let challenge = Data("SORA wallet recovery signing-key verification v1".utf8)
            let signature = try SigningWrapper(
                keystore: keystore,
                account: account,
                recoverySettings: nil
            ).sign(challenge)

            switch account.cryptoType {
            case .sr25519:
                guard let signature = signature as? SNSignature else {
                    return false
                }
                let publicKey = try SNPublicKey(rawData: account.publicKeyData)
                return SNSignatureVerifier().verify(
                    signature,
                    forOriginalData: challenge,
                    using: publicKey
                )
            case .ed25519:
                let publicKey = try EDPublicKey(rawData: account.publicKeyData)
                return EDSignatureVerifier().verify(
                    signature,
                    forOriginalData: challenge,
                    usingPublicKey: publicKey
                )
            case .ecdsa:
                let publicKey = try SECPublicKey(rawData: account.publicKeyData)
                return SECSignatureVerifier().verify(
                    signature,
                    forOriginalData: try challenge.blake2b32(),
                    usingPublicKey: publicKey
                )
            }
        } catch {
            Logger.shared.error("Retained wallet signing-key verification failed: \(error)")
            return false
        }
    }
}

extension SelectedWalletSettings {
    var currentAccount: AccountItem? {
        return value
    }
}
