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
import CoreData
import Security
import RobinHood
import SoraKeystore
import IrohaCrypto
import SSFUtils
import SSFCrypto
import SSFCloudStorage

protocol SelectedWalletSettingsProtocol: AnyObject {
    var currentAccount: AccountItem? { get }
    func performSave(
        value: AccountItem,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    )
    func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void)
    func save(value: AccountItem)
}

enum WalletTransactionSigningAvailability: Equatable {
    case available
    case recoveryRequired
    case missingKey
}

private struct SigningKeyPreservationAccountItem: RobinHood.Identifiable {
    let identifier: String
    let account: AccountItem?
}

/// A fetch-only mapper that never lets one malformed legacy row abort preservation for every
/// other wallet. Rows without enough public identity to verify a signer are returned as nil.
private final class SigningKeyPreservationAccountItemMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = SigningKeyPreservationAccountItem
    typealias CoreDataEntity = CDAccountItem

    var entityIdentifierFieldName: String {
        #keyPath(CoreDataEntity.identifier)
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws {
        guard let account = model.account else {
            throw AccountItemMapperError.invalidEntity
        }
        try AccountItemMapper().populate(entity: entity, from: account, using: context)
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let identifier = entity.identifier ?? entity.objectID.uriRepresentation().absoluteString
        guard
            let address = entity.identifier,
            let publicKey = entity.publicKey,
            let cryptoType = CryptoType(rawValue: UInt8(entity.cryptoType))
        else {
            return SigningKeyPreservationAccountItem(identifier: identifier, account: nil)
        }

        let settings = AccountSettings(
            visibleAssetIds: entity.settings?.visibleAssets as? [String],
            orderedAssetIds: entity.settings?.orderedAssets as? [String]
        )
        let account = AccountItem(
            address: address,
            cryptoType: cryptoType,
            networkType: SNAddressType(UInt8(entity.networkType)),
            username: entity.username ?? "",
            publicKeyData: publicKey,
            settings: settings,
            order: entity.order,
            isSelected: entity.isSelected
        )
        return SigningKeyPreservationAccountItem(identifier: identifier, account: account)
    }
}

protocol RetainedSigningMaterialCandidateProviding {
    func loadAccessibleSigningMaterialCandidates() -> [Data]
}

struct AccessibleKeychainRetainedSigningMaterialCandidateProvider:
    RetainedSigningMaterialCandidateProviding
{
    private struct ItemReference {
        let securityClass: CFString
        let persistentReference: Data
    }

    func loadAccessibleSigningMaterialCandidates() -> [Data] {
        let securityClasses: [(value: CFString, name: String)] = [
            (kSecClassKey, "key"),
            (kSecClassGenericPassword, "generic-password")
        ]
        var candidates = Set<Data>()

        for securityClass in securityClasses {
            let references = persistentReferences(
                for: securityClass.value,
                named: securityClass.name
            )
            var successfulReads = 0
            var candidateSizedValues = 0
            var readFailures: [OSStatus: Int] = [:]
            var unsupportedReadResults = 0

            for reference in references {
                let result = data(for: reference)
                guard result.status == errSecSuccess else {
                    readFailures[result.status, default: 0] += 1
                    continue
                }
                guard let data = result.data else {
                    unsupportedReadResults += 1
                    continue
                }

                successfulReads += 1
                let normalizedCandidates = normalizedCandidates(from: data)
                candidateSizedValues += normalizedCandidates.count
                candidates.formUnion(normalizedCandidates)
            }

            let failureSummary = readFailures
                .sorted { $0.key < $1.key }
                .map { "\($0.key):\($0.value)" }
                .joined(separator: ",")
            Logger.shared.info(
                "SORA retained-wallet accessible Keychain scan summary: " +
                    "class=\(securityClass.name) refs=\(references.count) " +
                    "reads=\(successfulReads) readFailures=\(failureSummary.isEmpty ? "none" : failureSummary) " +
                    "unsupportedResults=\(unsupportedReadResults) " +
                    "candidateSized=\(candidateSizedValues)"
            )
        }

        return Array(candidates)
    }

    private func normalizedCandidates(from data: Data) -> Set<Data> {
        let candidateLengths = Set([16, 20, 24, 28, 32, 64])
        var candidates = Set<Data>()

        if candidateLengths.contains(data.count) {
            candidates.insert(data)
        }

        guard data.count <= 65_536 else {
            return candidates
        }

        if let text = String(data: data, encoding: .utf8) {
            appendNormalizedCandidate(
                from: text,
                candidateLengths: candidateLengths,
                to: &candidates
            )
        }

        if let object = try? JSONSerialization.jsonObject(with: data) {
            var remainingStrings = 128
            appendNormalizedCandidates(
                from: object,
                candidateLengths: candidateLengths,
                remainingStrings: &remainingStrings,
                to: &candidates
            )
        }

        return candidates
    }

    private func appendNormalizedCandidates(
        from object: Any,
        candidateLengths: Set<Int>,
        remainingStrings: inout Int,
        to candidates: inout Set<Data>
    ) {
        guard remainingStrings > 0 else {
            return
        }

        if let string = object as? String {
            remainingStrings -= 1
            appendNormalizedCandidate(
                from: string,
                candidateLengths: candidateLengths,
                to: &candidates
            )
        } else if let dictionary = object as? [String: Any] {
            for value in dictionary.values where remainingStrings > 0 {
                appendNormalizedCandidates(
                    from: value,
                    candidateLengths: candidateLengths,
                    remainingStrings: &remainingStrings,
                    to: &candidates
                )
            }
        } else if let array = object as? [Any] {
            for value in array where remainingStrings > 0 {
                appendNormalizedCandidates(
                    from: value,
                    candidateLengths: candidateLengths,
                    remainingStrings: &remainingStrings,
                    to: &candidates
                )
            }
        }
    }

    private func appendNormalizedCandidate(
        from source: String,
        candidateLengths: Set<Int>,
        to candidates: inout Set<Data>
    ) {
        let value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= 4_096 else {
            return
        }

        if
            let decoded = Data(base64Encoded: value),
            candidateLengths.contains(decoded.count)
        {
            candidates.insert(decoded)
        }

        if
            let decoded = try? Data(hexStringSSF: value),
            candidateLengths.contains(decoded.count)
        {
            candidates.insert(decoded)
        }

        let words = value.split(whereSeparator: { $0.isWhitespace })
        if [12, 15, 18, 21, 24].contains(words.count) {
            let mnemonic = words.joined(separator: " ")
            if let seed = try? SeedFactory().deriveSeed(
                from: mnemonic,
                password: ""
            ).seed.miniSeed {
                candidates.insert(seed)
            }
        }
    }

    private func persistentReferences(
        for securityClass: CFString,
        named securityClassName: String
    ) -> [ItemReference] {
        let query: [String: Any] = [
            kSecClass as String: securityClass,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnPersistentRef as String: kCFBooleanTrue as Any,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            Logger.shared.warning(
                "SORA retained-wallet accessible Keychain scan unavailable: " +
                    "class=\(securityClassName) status=\(status)"
            )
            return []
        }

        if let references = result as? [Data] {
            return references.map {
                ItemReference(
                    securityClass: securityClass,
                    persistentReference: $0
                )
            }
        }
        if let reference = result as? Data {
            return [
                ItemReference(
                    securityClass: securityClass,
                    persistentReference: reference
                )
            ]
        }

        Logger.shared.warning(
            "SORA retained-wallet accessible Keychain scan returned an unsupported result: " +
                "class=\(securityClassName)"
        )
        return []
    }

    private func data(for reference: ItemReference) -> (status: OSStatus, data: Data?) {
        let query: [String: Any] = [
            kSecClass as String: reference.securityClass,
            kSecValuePersistentRef as String: reference.persistentReference,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        return (status, status == errSecSuccess ? result as? Data : nil)
    }
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
    private static let signingKeyPreservationLock = NSLock()

    let operationQueue: OperationQueue

    init(storageFacade: StorageFacadeProtocol, operationQueue: OperationQueue) {
        self.operationQueue = operationQueue

        super.init(storageFacade: storageFacade)
    }

    override func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void) {
        let mapper = AccountItemMapper()

        // Keep the boot-critical selected-account lookup isolated. A malformed legacy
        // unselected row must never stop an otherwise valid selected wallet from launching.
        let repository = storageFacade.createRepository(
            filter: NSPredicate.selectedAccount(),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )
        let allAccountsRepository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(SigningKeyPreservationAccountItemMapper())
        )

        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let operation = repository.fetchAllOperation(with: options)
        let preservationOperation = allAccountsRepository.fetchAllOperation(with: options)

        preservationOperation.completionBlock = {
            do {
                let accounts = try preservationOperation.extractNoCancellableResultData()
                    .compactMap(\.account)
                Self.reconcileSigningKeyPreservations(
                    keystore: Keychain(),
                    accounts: accounts
                )
            } catch {
                // This is deliberately best-effort and independent of selected-wallet boot.
                Logger.shared.error(
                    "SORA multi-wallet signer preservation scan failed; selected-wallet launch continues"
                )
            }
        }

        operation.completionBlock = {
            do {
                let result = try operation.extractNoCancellableResultData().first
                if let result {
                    _ = try? Self.reconcileSigningKeyPreservation(
                        keystore: Keychain(),
                        account: result
                    )
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

        operationQueue.addOperations(
            [operation, preservationOperation],
            waitUntilFinished: false
        )
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
                _ = try? Self.reconcileSigningKeyPreservation(
                    keystore: Keychain(),
                    account: value
                )
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

    static func transactionSigningAvailability(
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol,
        account: AccountItem,
        attemptRepair: Bool = true
    ) -> WalletTransactionSigningAvailability {
        if matchesRetainedRecoveryIdentity(settings: settings, account: account) {
            if attemptRepair {
                _ = try? repairRetainedSigningMaterialIfPossible(
                    settings: settings,
                    keystore: keystore,
                    account: account
                )
            }

            if matchesRetainedRecoveryIdentity(settings: settings, account: account) {
                return .recoveryRequired
            }
        }

        if attemptRepair {
            _ = try? reconcileSigningKeyPreservation(
                keystore: keystore,
                account: account
            )
        }

        guard let secret = try? keystore.fetchSecretKeyForAddress(account.address) else {
            return .missingKey
        }

        guard isVerifiedSigningSecret(secret, account: account) else {
            return .missingKey
        }

        return .available
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
        try repairRetainedSigningMaterialIfPossible(
            settings: settings,
            keystore: keystore,
            account: account,
            // Root setup, wallet creation, and signing availability call this overload
            // synchronously. Never enumerate the entire Keychain from those UI paths.
            materialCandidateProvider: nil
        )
    }

    static func repairRetainedSigningMaterialIfPossible(
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol,
        account: AccountItem,
        materialCandidateProvider: RetainedSigningMaterialCandidateProviding?
    ) throws -> Bool {
        guard matchesRetainedRecoveryIdentity(settings: settings, account: account) else {
            logAutomaticRecoveryBlocked(reason: "retained-identity-mismatch")
            return false
        }

        if try reconcileSigningKeyPreservation(keystore: keystore, account: account) {
            clearRetainedRecoveryState(settings: settings)
            Logger.shared.info(
                "SORA retained wallet signing material repaired automatically: preserved-or-canonical-secret"
            )
            return true
        }

        // Never pass an arbitrary retained secret into the native sr25519 signer. Some
        // malformed 64-byte encodings can panic below Swift's throwable boundary. The
        // independent fallible parser must prove that these exact bytes encode the retained
        // public key before the same bytes are used for a live signing challenge.
        let existingSecret = try keystore.fetchSecretKeyForAddress(account.address)

        guard existingSecret == nil else {
            logAutomaticRecoveryBlocked(reason: "existing-scoped-secret-invalid")
            return false
        }

        let derivationPath = try keystore.fetchDeriviationForAddress(account.address) ?? ""
        let scopedSeed = try keystore.fetchSeedForAddress(account.address)
        let scopedEntropy = try keystore.fetchEntropyForAddress(account.address)
        var candidates: [RetainedSigningMaterial]

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
                if candidates.isEmpty, let materialCandidateProvider {
                    candidates = retainedAccessibleSigningMaterialCandidates(
                        provider: materialCandidateProvider,
                        account: account
                    )
                }
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

            _ = try? reconcileSigningKeyPreservation(
                keystore: keystore,
                account: account
            )

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

    private static func retainedAccessibleSigningMaterialCandidates(
        provider: RetainedSigningMaterialCandidateProviding,
        account: AccountItem
    ) -> [RetainedSigningMaterial] {
        guard account.cryptoType == .sr25519 else {
            return []
        }

        let candidates = provider.loadAccessibleSigningMaterialCandidates()
        var matchesBySecret: [Data: RetainedSigningMaterial] = [:]

        for candidate in candidates {
            if
                candidate.count == 64,
                SNSafeKeypairValidator.isValidSr25519SecretKey(
                    candidate,
                    publicKey: account.publicKeyData
                )
            {
                matchesBySecret[candidate] = RetainedSigningMaterial(
                    secretKey: candidate,
                    seed: nil,
                    entropy: nil,
                    source: "accessible-unlabeled-secret"
                )
            }

            if let seedMaterial = try? retainedSigningMaterial(
                seed: candidate,
                entropy: nil,
                derivationPath: "",
                source: "accessible-unlabeled-seed",
                account: account
            ) {
                matchesBySecret[seedMaterial.secretKey] = seedMaterial
            }

            if
                [16, 20, 24, 28, 32].contains(candidate.count),
                let entropyMaterial = try? retainedSigningMaterial(
                    entropy: candidate,
                    derivationPath: "",
                    source: "accessible-unlabeled-entropy",
                    account: account
                )
            {
                matchesBySecret[entropyMaterial.secretKey] = entropyMaterial
            }
        }

        let matches = Array(matchesBySecret.values)

        Logger.shared.info(
            "SORA retained-wallet accessible Keychain candidate validation: " +
                "candidateSized=\(candidates.count) identityMatches=\(matches.count)"
        )
        return matches
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

    /// Unlike the legacy repair helper, this check never backfills recovery state from
    /// `selectedAccount`. Silent cloud recovery requires an already-persisted expected
    /// identity so every failure path remains completely read-only.
    static func hasExactStoredRetainedRecoveryIdentity(
        settings: SettingsManagerProtocol,
        account: AccountItem
    ) -> Bool {
        guard
            settings.bool(for: RetainedAccountRepairKey.recoveryRequired) == true,
            let retainedAccount = settings.value(
                of: AccountItem.self,
                for: RetainedAccountRepairKey.recoveryAccount
            ),
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

    @discardableResult
    static func completeRetainedCloudRecovery(
        settings: SettingsManagerProtocol,
        account: AccountItem
    ) -> Bool {
        guard hasExactStoredRetainedRecoveryIdentity(
            settings: settings,
            account: account
        ) else {
            return false
        }

        clearRetainedRecoveryState(settings: settings)
        return true
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
        settings.removeValue(for: "walletMigrationRecoveryReason")
        settings.removeValue(for: RetainedAccountRepairKey.recoveryAccount)
        // This required marker is the fail-closed commit bit and must be removed last.
        settings.removeValue(for: RetainedAccountRepairKey.recoveryRequired)
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

    /// Keeps a second, versioned copy of a verified SORA signer and restores the canonical
    /// address-scoped tag only when that canonical item is absent. Both writes use `addKey`,
    /// so neither an existing canonical signer nor an existing preservation record is ever
    /// overwritten. The source record is never deleted by automatic recovery.
    static func reconcileSigningKeyPreservations(
        keystore: KeystoreProtocol,
        accounts: [AccountItem]
    ) {
        accounts.forEach { account in
            _ = try? reconcileSigningKeyPreservation(
                keystore: keystore,
                account: account
            )
        }
    }

    static func reconcileSigningKeyPreservation(
        keystore: KeystoreProtocol,
        account: AccountItem
    ) throws -> Bool {
        signingKeyPreservationLock.lock()
        defer { signingKeyPreservationLock.unlock() }

        let canonicalIdentifier = KeystoreTag.secretKeyTagForAddress(account.address)
        let preservedIdentifier = KeystoreTag.preservedSecretKeyTagForAddress(account.address)
        let canonicalSecret = try keystore.fetchSecretKeyForAddress(account.address)

        if let canonicalSecret {
            guard isVerifiedSigningSecret(canonicalSecret, account: account) else {
                Logger.shared.error("SORA canonical wallet signer failed identity verification")
                return false
            }

            let preservedSecret = try keystore.fetchPreservedSecretKeyForAddress(account.address)
            if let preservedSecret {
                if preservedSecret != canonicalSecret ||
                    !isVerifiedSigningSecret(preservedSecret, account: account) {
                    Logger.shared.error(
                        "SORA wallet signer preservation conflict; existing record was left unchanged"
                    )
                }
                return true
            }

            do {
                try keystore.addKey(canonicalSecret, with: preservedIdentifier)
            } catch {
                // Another serialized writer may have created the item first. Never update it;
                // accept only an exact, independently verified value.
                let currentPreserved = try? keystore.fetchPreservedSecretKeyForAddress(
                    account.address
                )
                if currentPreserved != canonicalSecret {
                    Logger.shared.error("SORA wallet signer preservation write was unavailable")
                }
                return true
            }

            guard
                try keystore.fetchPreservedSecretKeyForAddress(account.address) == canonicalSecret
            else {
                try? keystore.deleteKeyIfExists(for: preservedIdentifier)
                Logger.shared.error("SORA wallet signer preservation read-back failed")
                return true
            }

            Logger.shared.info("SORA wallet signer preservation record created")
            return true
        }

        guard
            let preservedSecret = try keystore.fetchPreservedSecretKeyForAddress(account.address),
            isVerifiedSigningSecret(preservedSecret, account: account)
        else {
            return false
        }

        var createdCanonical = false
        do {
            try keystore.addKey(preservedSecret, with: canonicalIdentifier)
            createdCanonical = true
        } catch {
            // Never call updateKey here. If an item appeared concurrently, accept only the
            // exact retained signer; otherwise fail closed and leave both records untouched.
        }

        guard
            try keystore.fetchSecretKeyForAddress(account.address) == preservedSecret,
            isVerifiedSigningSecret(preservedSecret, account: account)
        else {
            if createdCanonical,
               (try? keystore.fetchSecretKeyForAddress(account.address)) == preservedSecret {
                try? keystore.deleteKeyIfExists(for: canonicalIdentifier)
            }
            return false
        }

        Logger.shared.info("SORA wallet signer restored from its preservation record")
        return true
    }

    private static func isVerifiedSigningSecret(
        _ secretKey: Data,
        account: AccountItem
    ) -> Bool {
        guard
            let derivedAddress = try? SS58AddressFactory().address(
                fromAccountId: account.publicKeyData,
                type: account.networkType
            ),
            derivedAddress == account.address
        else {
            return false
        }

        do {
            let challenge = Data("SORA wallet recovery signing-key verification v1".utf8)

            switch account.cryptoType {
            case .sr25519:
                return SNSafeKeypairValidator.isValidSr25519SecretKey(
                    secretKey,
                    publicKey: account.publicKeyData
                ) && hasVerifiedSr25519SigningKey(secretKey: secretKey, account: account)
            case .ed25519:
                let keypair = try Ed25519KeypairFactory().createKeypairFromSeed(
                    secretKey.miniSeed,
                    chaincodeList: []
                )
                guard keypair.publicKey().rawData() == account.publicKeyData else {
                    return false
                }
                let signature = try EDSigner(privateKey: keypair.privateKey()).sign(challenge)
                return EDSignatureVerifier().verify(
                    signature,
                    forOriginalData: challenge,
                    usingPublicKey: try EDPublicKey(rawData: account.publicKeyData)
                )
            case .ecdsa:
                let keypair = try EcdsaKeypairFactory().createKeypairFromSeed(
                    secretKey.miniSeed,
                    chaincodeList: []
                )
                guard keypair.publicKey().rawData() == account.publicKeyData else {
                    return false
                }
                let hashedChallenge = try challenge.blake2b32()
                let signature = try SECSigner(privateKey: keypair.privateKey()).sign(
                    hashedChallenge
                )
                return SECSignatureVerifier().verify(
                    signature,
                    forOriginalData: hashedChallenge,
                    usingPublicKey: try SECPublicKey(rawData: account.publicKeyData)
                )
            }
        } catch {
            Logger.shared.error("SORA wallet signer identity verification failed: \(error)")
            return false
        }
    }

    private static func hasVerifiedSr25519SigningKey(
        secretKey: Data,
        account: AccountItem
    ) -> Bool {
        do {
            let challenge = Data("SORA wallet recovery signing-key verification v1".utf8)
            let privateKey = try SNPrivateKey(rawData: secretKey)
            let publicKey = try SNPublicKey(rawData: account.publicKeyData)
            let signature = try SNSigner(
                keypair: SNKeypair(privateKey: privateKey, publicKey: publicKey)
            ).sign(challenge)

            return SNSignatureVerifier().verify(
                signature,
                forOriginalData: challenge,
                using: publicKey
            )
        } catch {
            Logger.shared.error(
                "Retained wallet existing sr25519 signing-key verification failed: \(error)"
            )
            return false
        }
    }
}

extension SelectedWalletSettings {
    var currentAccount: AccountItem? {
        return value
    }
}

// MARK: - Post-authentication retained-wallet cloud recovery

protocol RetainedWalletCloudRecoveryProtocol: AnyObject {
    @discardableResult
    func recoverAfterLocalAuthentication(protectedDataAvailable: Bool) async -> Bool
}

struct RetainedWalletBackupKeyMaterial {
    let identifier: String
    let data: Data
    let isSigningKey: Bool
}

struct RetainedWalletBackupCandidate {
    let account: AccountItem
    let verificationKeystore: KeystoreProtocol
    let keyMaterial: [RetainedWalletBackupKeyMaterial]
}

protocol RetainedWalletBackupCandidateDeriving {
    func deriveCandidate(
        from backup: OpenBackupAccount,
        password: String
    ) throws -> RetainedWalletBackupCandidate
}

enum RetainedWalletCloudRecoveryError: Error {
    case unsupportedBackup
    case missingSigningKey
    case timeout
}

final class AccountOperationRetainedWalletBackupCandidateDeriver:
    RetainedWalletBackupCandidateDeriving
{
    func deriveCandidate(
        from backup: OpenBackupAccount,
        password: String
    ) throws -> RetainedWalletBackupCandidate {
        let inMemoryKeystore = InMemoryKeychain()
        let factory = AccountOperationFactory(keystore: inMemoryKeystore)
        let backupTypes = backup.backupAccountType ?? []
        let operation: BaseOperation<AccountItem>
        let cryptoType = CryptoType(type: backup.cryptoType ?? "SR25519")
        let derivationPath = backup.substrateDerivationPath ?? ""

        if backupTypes.contains(.passphrase),
           let passphrase = backup.passphrase,
           !passphrase.isEmpty
        {
            let mnemonic = try IRMnemonicCreator().mnemonic(fromList: passphrase)
            let request = AccountCreationRequest(
                username: backup.name ?? "",
                type: .sora,
                derivationPath: derivationPath,
                cryptoType: cryptoType
            )
            operation = factory.newAccountOperation(request: request, mnemonic: mnemonic)
        } else if backupTypes.contains(.seed),
                  let seed = backup.encryptedSeed?.substrateSeed,
                  !seed.isEmpty
        {
            let request = AccountImportSeedRequest(
                seed: seed,
                username: backup.name ?? "",
                networkType: .sora,
                derivationPath: derivationPath,
                cryptoType: cryptoType
            )
            operation = factory.newAccountOperation(request: request)
        } else {
            // JSON backups contain an independently supplied raw secret key. Automatic
            // recovery must never pass those bytes to the native sr25519 signer: malformed
            // encodings can panic below Swift's throwable boundary. Manual JSON import
            // remains available through its existing, user-initiated flow.
            throw RetainedWalletCloudRecoveryError.unsupportedBackup
        }

        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let account = try operation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        let identifiers = [
            KeystoreTag.entropyTagForAddress(account.address),
            KeystoreTag.deriviationTagForAddress(account.address),
            KeystoreTag.seedTagForAddress(account.address),
            KeystoreTag.secretKeyTagForAddress(account.address)
        ]
        let keyMaterial: [RetainedWalletBackupKeyMaterial] = try identifiers.compactMap { identifier -> RetainedWalletBackupKeyMaterial? in
            guard let data = try inMemoryKeystore.loadIfKeyExists(identifier) else {
                return nil
            }

            return RetainedWalletBackupKeyMaterial(
                identifier: identifier,
                data: data,
                isSigningKey: identifier == KeystoreTag.secretKeyTagForAddress(account.address)
            )
        }

        guard keyMaterial.contains(where: { $0.isSigningKey }) else {
            throw RetainedWalletCloudRecoveryError.missingSigningKey
        }

        return RetainedWalletBackupCandidate(
            account: account,
            verificationKeystore: inMemoryKeystore,
            keyMaterial: keyMaterial
        )
    }
}

private final class RetainedWalletCloudResultGate<Value> {
    private let lock = NSLock()
    private var completed = false

    func resume(
        _ continuation: CheckedContinuation<Result<Value, Error>, Never>,
        with result: Result<Value, Error>
    ) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        lock.unlock()
        continuation.resume(returning: result)
    }
}

final class RetainedWalletCloudRecoveryService: RetainedWalletCloudRecoveryProtocol {
    typealias SigningVerifier = (KeystoreProtocol, AccountItem) -> Bool

    private struct RecoveryGateKey: Hashable {
        let settingsIdentifier: ObjectIdentifier
        let address: String
    }

    private static let recoveryGateLock = NSLock()
    private static var recoveriesInFlight = Set<RecoveryGateKey>()

    private let settings: SettingsManagerProtocol
    private let keystore: KeystoreProtocol
    private let cloudStorage: CloudStorageServiceProtocol
    private let selectedAccountProvider: () -> AccountItem?
    private let candidateDeriver: RetainedWalletBackupCandidateDeriving
    private let signingVerifier: SigningVerifier
    private let materialCandidateProvider: RetainedSigningMaterialCandidateProviding?
    private let cloudTimeout: TimeInterval

    init(
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol,
        cloudStorage: CloudStorageServiceProtocol,
        selectedAccountProvider: @escaping () -> AccountItem?,
        candidateDeriver: RetainedWalletBackupCandidateDeriving =
            AccountOperationRetainedWalletBackupCandidateDeriver(),
        signingVerifier: @escaping SigningVerifier = {
            SelectedWalletSettings.hasVerifiedSigningKey(keystore: $0, account: $1)
        },
        materialCandidateProvider: RetainedSigningMaterialCandidateProviding? = nil,
        cloudTimeout: TimeInterval = 5
    ) {
        self.settings = settings
        self.keystore = keystore
        self.cloudStorage = cloudStorage
        self.selectedAccountProvider = selectedAccountProvider
        self.candidateDeriver = candidateDeriver
        self.signingVerifier = signingVerifier
        self.materialCandidateProvider = materialCandidateProvider
        self.cloudTimeout = cloudTimeout
    }

    static func live() -> RetainedWalletCloudRecoveryService {
        RetainedWalletCloudRecoveryService(
            settings: SettingsManager.shared,
            keystore: Keychain(),
            cloudStorage: CloudStorageService(uiDelegate: nil),
            selectedAccountProvider: { SelectedWalletSettings.shared.currentAccount },
            materialCandidateProvider: AccessibleKeychainRetainedSigningMaterialCandidateProvider()
        )
    }

    @discardableResult
    func recoverAfterLocalAuthentication(protectedDataAvailable: Bool) async -> Bool {
        guard protectedDataAvailable,
              let retainedAccount = selectedAccountProvider(),
              SelectedWalletSettings.hasExactStoredRetainedRecoveryIdentity(
                  settings: settings,
                  account: retainedAccount
              )
        else {
            return false
        }

        let recoveryGateKey = RecoveryGateKey(
            settingsIdentifier: ObjectIdentifier(settings),
            address: retainedAccount.address
        )
        guard Self.beginRecovery(for: recoveryGateKey) else {
            return false
        }
        defer {
            Self.endRecovery(for: recoveryGateKey)
        }

        do {
            // Known, account-scoped tags are cheap and safe to check before any network work.
            if try SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                settings: settings,
                keystore: keystore,
                account: retainedAccount,
                materialCandidateProvider: nil
            ) {
                return true
            }

            // A present canonical signer is never inspected, replaced, or deleted by cloud
            // recovery. Local retained-material recovery owns that case.
            guard try keystore.fetchSecretKeyForAddress(retainedAccount.address) == nil else {
                return false
            }

            // Prefer the bounded, exact-address cloud recovery path. A full Keychain scan is
            // only a best-effort fallback and must never delay a usable cloud backup.
            if let pinData = try? keystore.fetchKey(for: KeystoreTag.pincode.rawValue),
               let pin = String(data: pinData, encoding: .utf8),
               !pin.isEmpty {
                do {
                    let backup = try await fetchSilentBackup(
                        address: retainedAccount.address,
                        password: pin
                    )
                    try Task.checkCancellation()

                    if backup.address == retainedAccount.address {
                        let candidate = try candidateDeriver.deriveCandidate(
                            from: backup,
                            password: pin
                        )
                        if candidateMatches(candidate.account, retainedAccount: retainedAccount),
                           signingVerifier(candidate.verificationKeystore, candidate.account),
                           SelectedWalletSettings.hasExactStoredRetainedRecoveryIdentity(
                               settings: settings,
                               account: retainedAccount
                           ),
                           try persistVerifiedCandidate(
                               candidate,
                               retainedAccount: retainedAccount
                           ) {
                            return true
                        }
                    }
                } catch {
                    Logger.shared.warning("SORA silent retained-wallet cloud recovery unavailable")
                }
            }

            guard let materialCandidateProvider else {
                return false
            }

            // Security.framework enumeration and candidate derivation can be slow for a large
            // Keychain. Keep it on a utility queue and out of every launch/MainActor path.
            return await repairFromAccessibleKeychain(
                retainedAccount: retainedAccount,
                materialCandidateProvider: materialCandidateProvider
            )
        } catch {
            Logger.shared.warning("SORA retained-wallet automatic recovery unavailable")
            return false
        }
    }

    private func repairFromAccessibleKeychain(
        retainedAccount: AccountItem,
        materialCandidateProvider: RetainedSigningMaterialCandidateProviding
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [settings, keystore] in
                let didRepair = (try? SelectedWalletSettings.repairRetainedSigningMaterialIfPossible(
                    settings: settings,
                    keystore: keystore,
                    account: retainedAccount,
                    materialCandidateProvider: materialCandidateProvider
                )) ?? false
                continuation.resume(returning: didRepair)
            }
        }
    }

    private static func beginRecovery(for key: RecoveryGateKey) -> Bool {
        recoveryGateLock.lock()
        defer { recoveryGateLock.unlock() }
        return recoveriesInFlight.insert(key).inserted
    }

    private static func endRecovery(for key: RecoveryGateKey) {
        recoveryGateLock.lock()
        recoveriesInFlight.remove(key)
        recoveryGateLock.unlock()
    }

    private func fetchSilentBackup(
        address: String,
        password: String
    ) async throws -> OpenBackupAccount {
        let gate = RetainedWalletCloudResultGate<OpenBackupAccount>()
        let result = await withCheckedContinuation {
            (continuation: CheckedContinuation<Result<OpenBackupAccount, Error>, Never>) in
            let requestTask = Task { [cloudStorage] in
                do {
                    let state = try await cloudStorage.restorePreviousSignInIfAvailable()
                    try Task.checkCancellation()
                    guard state == .authorized else {
                        throw CloudStorageServiceError.notAuthorized
                    }

                    let backup = try await cloudStorage.importMobileBackupIfAuthorized(
                        account: OpenBackupAccount(address: address),
                        password: password
                    )
                    try Task.checkCancellation()
                    gate.resume(continuation, with: .success(backup))
                } catch {
                    gate.resume(continuation, with: .failure(error))
                }
            }

            Task {
                let nanoseconds = UInt64(max(0, cloudTimeout) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                requestTask.cancel()
                gate.resume(
                    continuation,
                    with: .failure(RetainedWalletCloudRecoveryError.timeout)
                )
            }
        }

        return try result.get()
    }

    private func candidateMatches(
        _ candidate: AccountItem,
        retainedAccount: AccountItem
    ) -> Bool {
        candidate.address == retainedAccount.address &&
            candidate.publicKeyData == retainedAccount.publicKeyData &&
            candidate.networkType == retainedAccount.networkType &&
            candidate.cryptoType == retainedAccount.cryptoType
    }

    private func persistVerifiedCandidate(
        _ candidate: RetainedWalletBackupCandidate,
        retainedAccount: AccountItem
    ) throws -> Bool {
        guard SelectedWalletSettings.hasExactStoredRetainedRecoveryIdentity(
            settings: settings,
            account: retainedAccount
        ), try keystore.fetchSecretKeyForAddress(retainedAccount.address) == nil else {
            return false
        }

        var missingMaterial: [RetainedWalletBackupKeyMaterial] = []
        for material in candidate.keyMaterial {
            if let existing = try keystore.loadIfKeyExists(material.identifier) {
                guard existing == material.data else {
                    return false
                }
            } else {
                missingMaterial.append(material)
            }
        }

        // Supporting material is written before the signer; until the final add succeeds,
        // the wallet remains unable to sign. `addKey` is create-only and cannot overwrite.
        missingMaterial.sort { !$0.isSigningKey && $1.isSigningKey }
        var addedIdentifiers: [String] = []

        do {
            for material in missingMaterial {
                try keystore.addKey(material.data, with: material.identifier)
                addedIdentifiers.append(material.identifier)
            }

            for material in candidate.keyMaterial {
                guard try keystore.fetchKey(for: material.identifier) == material.data else {
                    throw RetainedWalletCloudRecoveryError.missingSigningKey
                }
            }

            guard signingVerifier(keystore, retainedAccount),
                  SelectedWalletSettings.completeRetainedCloudRecovery(
                      settings: settings,
                      account: retainedAccount
                  )
            else {
                throw RetainedWalletCloudRecoveryError.missingSigningKey
            }

            Logger.shared.info("SORA retained wallet recovered from an existing cloud session")
            return true
        } catch {
            for identifier in addedIdentifiers.reversed() {
                try? keystore.deleteKeyIfExists(for: identifier)
            }
            throw error
        }
    }
}
