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
import RobinHood
import CryptoKit
import SoraKeystore
import IrohaCrypto

enum LegacyWalletUpgradePolicy {
    static func isCandidate(
        keyIdentifiers: Set<String>,
        hasWatchOnlyWallet: Bool,
        snapshot: WalletNetworkSnapshot?,
        legacyIrohaKeyVerified: Bool = false
    ) -> Bool {
        let scopedSuffixes = [
            "-secretKey",
            "-entropy",
            "-deriv",
            "-seed",
        ]
        let hasScopedWallet = keyIdentifiers.contains {
            identifier in
            scopedSuffixes.contains {
                identifier.hasSuffix($0)
            }
        }
        // Some pre-account-model releases stored signing material under the
        // unscoped `privateKey` tag. Admit that pair only after the production
        // overload proves that it belongs to this exact retained entropy.
        let hasUnscopedPrivateKey = keyIdentifiers.contains("privateKey")
        return keyIdentifiers.contains(
            KeystoreTag.legacyEntropy.rawValue
        ) &&
            !hasScopedWallet &&
            (!hasUnscopedPrivateKey || legacyIrohaKeyVerified) &&
            !hasWatchOnlyWallet &&
            (snapshot?.selectedWalletId == nil) &&
            (snapshot?.wallets.isEmpty ?? true) &&
            (snapshot?.accounts.isEmpty ?? true)
    }

    static func isCandidate(
        keystore: KeystoreProtocol,
        hasWatchOnlyWallet: Bool,
        snapshot: WalletNetworkSnapshot?
    ) throws -> Bool {
        guard isCandidate(
            keyIdentifiers: Set(try keystore.allKeyIdentifiers()),
            hasWatchOnlyWallet: hasWatchOnlyWallet,
            snapshot: snapshot,
            legacyIrohaKeyVerified: true
        ) else { return false }
        var entropy = try keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue)
        defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
        try keystore.verifyLegacyIrohaKeyIfPresent(entropy: entropy)
        return true
    }

    static func shouldDeferStorageMigration(
        storeExists: Bool,
        keystore: KeystoreProtocol,
        hasWatchOnlyWallet: Bool,
        snapshot: WalletNetworkSnapshot?
    ) throws -> Bool {
        try !storeExists && isCandidate(
            keystore: keystore,
            hasWatchOnlyWallet: hasWatchOnlyWallet,
            snapshot: snapshot
        )
    }

    static func shouldDeferStorageMigration(
        storeExists: Bool,
        keyIdentifiers: Set<String>,
        hasWatchOnlyWallet: Bool,
        snapshot: WalletNetworkSnapshot?
    ) -> Bool {
        !storeExists && isCandidate(
            keyIdentifiers: keyIdentifiers,
            hasWatchOnlyWallet: hasWatchOnlyWallet,
            snapshot: snapshot
        )
    }
}

/// Resolves the pre-account-model display name without normalizing or moving
/// either retained source. Some production releases stored `userName` in
/// settings, while older installations kept the same UTF-8 value in Keychain.
/// Conflicting or malformed evidence is a recovery condition, not permission
/// to silently choose one value and change the wallet's visible identity.
enum LegacyWalletUpgradeDisplayNameResolver {
    private static let maximumUTF8Bytes = 4 * 1_024

    static func resolve(
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol
    ) throws -> String {
        let key = KeystoreTag.legacyUsername.rawValue

        let settingsName: String?
        if settings.allKeys().contains(key) {
            guard
                let retained = settings.anyValue(for: key) as? String,
                retained.utf8.count <= maximumUTF8Bytes
            else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }
            settingsName = retained
        } else {
            settingsName = nil
        }

        var keychainBytes = try keystore.loadIfKeyExists(key)
        defer {
            if let count = keychainBytes?.count {
                keychainBytes?.resetBytes(in: 0 ..< count)
            }
            keychainBytes = nil
        }
        let keychainName: String?
        if let keychainBytes {
            guard
                keychainBytes.count <= maximumUTF8Bytes,
                let retained = String(
                    data: keychainBytes,
                    encoding: .utf8
                ),
                retained.utf8.count == keychainBytes.count
            else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }
            keychainName = retained
        } else {
            keychainName = nil
        }

        switch (settingsName, keychainName) {
        case let (settingsName?, keychainName?):
            guard settingsName == keychainName else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }
            return settingsName
        case let (settingsName?, nil):
            return settingsName
        case let (nil, keychainName?):
            return keychainName
        case (nil, nil):
            return ""
        }
    }
}

/// Activates the account model for an unsuffixed legacy entropy record without
/// copying, normalizing, or replacing any secret. The normal importer remains
/// responsible only for in-memory derivation and identity verification.
enum LegacyWalletUpgradeSecretRetention {
    static func consumeWithoutPersisting(
        _ prepared: PreparedAccount,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        expectedEntropyDigest: Data,
        expectedDisplayName: String,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws {
        try recoveryGate
            .requireAuthorizedLifecycleContinuation()
        let account = prepared.account
        guard
            account.username == expectedDisplayName,
            try LegacyWalletUpgradeDisplayNameResolver.resolve(
                settings: settings,
                keystore: keystore
            ) == expectedDisplayName
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }
        let scopedTags = [
            KeystoreTag.secretKeyTagForAddress(account.address),
            KeystoreTag.entropyTagForAddress(account.address),
            KeystoreTag.deriviationTagForAddress(account.address),
            KeystoreTag.seedTagForAddress(account.address),
        ]
        let identifiers = Set(try keystore.allKeyIdentifiers())
        guard
            scopedTags.allSatisfy({ !identifiers.contains($0) })
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }

        var retainedEntropy = try keystore.fetchKey(
            for: KeystoreTag.legacyEntropy.rawValue
        )
        defer {
            retainedEntropy.resetBytes(
                in: retainedEntropy.startIndex ..< retainedEntropy.endIndex
            )
        }
        let mnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: retainedEntropy)
        try keystore.verifyLegacyIrohaKeyIfPresent(entropy: retainedEntropy)
        guard
            !retainedEntropy.isEmpty,
            Data(SHA256.hash(data: retainedEntropy)) ==
                expectedEntropyDigest,
            WalletMnemonicWordPolicy.retainedSoraWordCounts
                .contains(mnemonic.allWords().count)
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }
        try LegacySoraIdentityValidator.validate(
            address: account.address,
            publicKey: account.publicKeyData,
            cryptoType: account.cryptoType,
            networkType: account.networkType,
            derivationPath: nil,
            entropy: retainedEntropy,
            rawSeed: nil,
            secret: nil,
            recoveryGate: recoveryGate
        )

        // Wipe the normal importer's derived copies instead of persisting them.
        prepared.discard()

        var verifiedRetainedEntropy = try keystore.fetchKey(
            for: KeystoreTag.legacyEntropy.rawValue
        )
        defer {
            verifiedRetainedEntropy.resetBytes(
                in: verifiedRetainedEntropy.startIndex ..<
                    verifiedRetainedEntropy.endIndex
            )
        }
        let postIdentifiers = Set(try keystore.allKeyIdentifiers())
        try keystore.verifyLegacyIrohaKeyIfPresent(entropy: verifiedRetainedEntropy)
        guard
            Data(SHA256.hash(data: verifiedRetainedEntropy)) ==
                expectedEntropyDigest,
            try LegacyWalletUpgradeDisplayNameResolver.resolve(
                settings: settings,
                keystore: keystore
            ) == expectedDisplayName,
            postIdentifiers.contains("privateKey") == identifiers.contains("privateKey"),
            scopedTags.allSatisfy({ !postIdentifiers.contains($0) })
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }
    }
}

/// Resumes only the first account activation backed by the original unsuffixed legacy keys.
/// It never grants unfinished ordinary imports permission to invent or replace wallet secrets.
enum LegacyWalletAccountCommitRecovery {
    enum Checkpoint {
        case proofVerified, journalBound, coreDataCommitted, networkModelActivated
        case selectionCommitted, activated, beforeRecoveryClear
    }

    @discardableResult
    static func recoverIfNeeded(
        storeURL: URL,
        modelDirectory: String,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        baseURL: URL? = nil,
        lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
        recoveryGate: WalletRecoveryCapabilityGate = .shared,
        startupVerificationMarker: WalletMigrationRecoveryMarker? = nil,
        checkpoint: (Checkpoint) throws -> Void = { _ in }
    ) throws -> Bool {
        let lease = lifecycleCoordinator.acquire()
        defer { lease.release() }
        var marker = WalletMigrationRecoveryMarker.capture(settings)
        if let startupVerificationMarker {
            try startupVerificationMarker.requireUnchangedForStartupVerification(settings)
            guard marker == startupVerificationMarker else {
                throw WalletNetworkMigrationError.walletRecoveryRequired
            }
        }
        func requireMarkerUnchanged() throws {
            if let startupVerificationMarker {
                try startupVerificationMarker.requireUnchangedForStartupVerification(settings)
                guard marker == startupVerificationMarker else {
                    throw WalletNetworkMigrationError.walletRecoveryRequired
                }
            } else {
                try marker.requireUnchangedForLegacyAccountRecovery(settings)
            }
        }
        var gate = verificationGate(settings: settings, marker: marker,
            startupVerificationMarker: startupVerificationMarker)
        var journalStore = try WalletAccountCommitJournalStore(baseURL: baseURL, recoveryGate: gate)
        let journals = try journalStore.journalsForLegacyRecovery()
        let unresolved = journals.filter { $0.stage != .activated }
        let candidates = unresolved.isEmpty && marker.required
            ? journals.filter { $0.recoveryMarker == marker } : unresolved
        guard !candidates.isEmpty else { return false }
        guard journals.count == 1, candidates.count == 1,
              candidates[0].expectedExistingWalletIds.isEmpty,
              !WalletRecoveryMigrationJournalProbe.hasUnresolvedMigration(storeURL: storeURL)
        else { throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed }
        var journal = candidates[0]
        try requireMarkerUnchanged()
        if let bound = journal.recoveryMarker {
            guard bound == marker else { throw WalletNetworkMigrationError.walletRecoveryRequired }
        }

        let originalIdentifiers = Set(try keystore.allKeyIdentifiers())
        var entropy = try keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue)
        defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
        let entropyDigest = Data(SHA256.hash(data: entropy))
        let displayName = try LegacyWalletUpgradeDisplayNameResolver.resolve(settings: settings, keystore: keystore)
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy)
        guard !entropy.isEmpty,
              WalletMnemonicWordPolicy.retainedSoraWordCounts.contains(mnemonic.allWords().count),
              try LegacyWalletUpgradePolicy.isCandidate(keystore: keystore,
                  hasWatchOnlyWallet: settings.hasRetainedWatchOnlyWallet(), snapshot: nil)
        else { throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed }
        let operation = AccountOperationFactory(keystore: keystore, recoveryGate: gate)
            .prepareAccountOperation(request: AccountCreationRequest(username: displayName,
                type: .sora, derivationPath: "", cryptoType: .sr25519), mnemonic: mnemonic)
        operation.start()
        let prepared = try operation.extractNoCancellableResultData()
        defer { prepared.discard() }
        let expected = prepared.account
        try LegacyWalletUpgradeSecretRetention.consumeWithoutPersisting(prepared, keystore: keystore,
            settings: settings, expectedEntropyDigest: entropyDigest, expectedDisplayName: displayName,
            recoveryGate: gate)
        guard expected.address == journal.walletId else {
            throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed
        }
        let model = try accountModel(modelDirectory: modelDirectory)
        var networkStore = try WalletNetworkStore(baseURL: baseURL, recoveryGate: gate)

        func prove(requireAccount: Bool = false, requireSnapshot: Bool = false) throws {
            try requireMarkerUnchanged()
            try journalStore.requireCurrentForLegacyRecovery(journal)
            guard Set(try keystore.allKeyIdentifiers()) == originalIdentifiers,
                  !settings.hasRetainedWatchOnlyWallet(),
                  try LegacyWalletUpgradeDisplayNameResolver.resolve(settings: settings, keystore: keystore) == displayName
            else { throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed }
            var retained = try keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue)
            defer { retained.resetBytes(in: retained.startIndex ..< retained.endIndex) }
            guard Data(SHA256.hash(data: retained)) == entropyDigest else {
                throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed
            }
            try keystore.verifyLegacyIrohaKeyIfPresent(entropy: retained)
            try LegacySoraIdentityValidator.validate(address: expected.address, publicKey: expected.publicKeyData,
                cryptoType: expected.cryptoType, networkType: expected.networkType, derivationPath: nil,
                entropy: retained, rawSeed: nil, secret: nil, recoveryGate: gate)
            let accounts = try readAccounts(storeURL: storeURL, model: model)
            let stageRequiresAccount = [.coreDataCommitted, .networkModelActivated, .activated].contains(journal.stage)
            guard accounts.isEmpty || accounts == [expected],
                  !(requireAccount || stageRequiresAccount) || accounts == [expected]
            else { throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed }
            let networkState = try networkStore.loadForLegacyFirstActivationRecovery()
            let snapshot = networkState.active ?? networkState.staged?.snapshot
            let stageRequiresSnapshot = [.networkModelActivated, .activated].contains(journal.stage)
            guard !(requireSnapshot || stageRequiresSnapshot) || networkState.active != nil,
                  snapshot == nil || accounts == [expected]
            else { throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed }
            let verifier = WalletNetworkModelMigrator(keystore: keystore, store: networkStore, settings: settings,
                lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate), recoveryGate: gate)
            let verified = try networkState.staged != nil
                ? verifier.verifiedFirstLegacySnapshot(accounts: [expected], selectedAddress: expected.address)
                : verifier.verifiedSnapshot(accounts: [expected], selectedAddress: expected.address)
            if let snapshot {
                guard snapshot.schemaVersion == verified.schemaVersion,
                      snapshot.selectedWalletId == verified.selectedWalletId,
                      snapshot.wallets == verified.wallets, snapshot.accounts == verified.accounts
                else { throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed }
            }
            let selectionKey = SettingsKey.selectedAccount.rawValue
            if settings.allKeys().contains(selectionKey) {
                guard accounts == [expected], networkState.active != nil,
                      settings.value(of: AccountItem.self, for: selectionKey) == expected
                else { throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed }
            } else if journal.stage == .activated {
                throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed
            }
            try requireMarkerUnchanged()
            try journalStore.requireCurrentForLegacyRecovery(journal)
        }

        try prove()
        try checkpoint(.proofVerified)
        try prove()
        // Publish a stable pending marker before resuming any durable stage. Startup's error
        // handling then preserves this generation even if this recovery itself is interrupted.
        if !marker.required {
            try WalletMigrationRecoveryMarker.synchronized {
                try requireMarkerUnchanged()
                settings.setWalletMigrationRecovery(reason: WalletMigrationRecoveryMarker.accountCommitInterruptionReason)
                marker = WalletMigrationRecoveryMarker.capture(settings)
                guard marker.isLegacyAccountCommitInterruption else {
                    throw WalletNetworkMigrationError.walletRecoveryRequired
                }
            }
            gate = verificationGate(settings: settings, marker: marker,
                startupVerificationMarker: startupVerificationMarker)
            journalStore = try WalletAccountCommitJournalStore(baseURL: baseURL, recoveryGate: gate)
            networkStore = try WalletNetworkStore(baseURL: baseURL, recoveryGate: gate)
        }
        journal = try journalStore.bindLegacyRecoveryMarker(journal, marker: marker)
        try checkpoint(.journalBound)
        try prove()
        if journal.stage == .prepared {
            journal = try journalStore.advance(journal, to: .secretsPersisted)
        }
        if journal.stage == .secretsPersisted {
            try prove()
            if try readAccounts(storeURL: storeURL, model: model).isEmpty {
                try insertFirstAccount(expected, storeURL: storeURL, model: model)
            }
            try checkpoint(.coreDataCommitted)
            try prove(requireAccount: true)
            journal = try journalStore.advance(journal, to: .coreDataCommitted)
        }
        if journal.stage == .coreDataCommitted {
            try prove(requireAccount: true)
            let migrator = WalletNetworkModelMigrator(keystore: keystore, store: networkStore, settings: settings,
                lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate), recoveryGate: gate)
            if let staged = try networkStore.loadForLegacyFirstActivationRecovery().staged {
                let verified = try migrator.verifiedFirstLegacySnapshot(
                    accounts: [expected], selectedAddress: expected.address)
                try prove(requireAccount: true)
                try journalStore.withCurrentForLegacyRecovery(journal) {
                    try WalletMigrationRecoveryMarker.synchronized {
                        try requireMarkerUnchanged()
                        guard journal.recoveryMarker == marker else {
                            throw WalletNetworkMigrationError.walletRecoveryRequired
                        }
                        try networkStore.activateVerifiedLegacyFirstSnapshot(staged, expected: verified)
                    }
                }
            }
            try migrator.migrate(accounts: [expected], selectedAddress: expected.address)
            try checkpoint(.networkModelActivated)
            try prove(requireAccount: true, requireSnapshot: true)
            journal = try journalStore.advance(journal, to: .networkModelActivated)
        }
        if journal.stage == .networkModelActivated {
            try prove(requireAccount: true, requireSnapshot: true)
            if !settings.allKeys().contains(SettingsKey.selectedAccount.rawValue) {
                settings.set(value: expected, for: SettingsKey.selectedAccount.rawValue)
            }
            try checkpoint(.selectionCommitted)
            try prove(requireAccount: true, requireSnapshot: true)
            guard settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue) == expected else {
                throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed
            }
            journal = try journalStore.advance(journal, to: .activated)
            try checkpoint(.activated)
        }
        try prove(requireAccount: true, requireSnapshot: true)
        try checkpoint(.beforeRecoveryClear)
        try prove(requireAccount: true, requireSnapshot: true)
        if startupVerificationMarker == nil {
            try marker.clearAfterVerifiedLegacyAccountActivation(settings)
            try recoveryGate.requireMutableWalletAccess()
        } else {
            // The outer startup verifier still has to prove the database and
            // full active network inventory before clearing this same marker.
            try requireMarkerUnchanged()
        }
        return true
    }

    private static func verificationGate(settings: SettingsManagerProtocol,
                                         marker: WalletMigrationRecoveryMarker,
                                         startupVerificationMarker: WalletMigrationRecoveryMarker? = nil) -> WalletRecoveryCapabilityGate {
        WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }, legacyAccountRecoveryMarker: marker,
            startupVerificationMarker: startupVerificationMarker)
    }

    private static func accountModel(modelDirectory: String) throws -> NSManagedObjectModel {
        let name = UserStorageVersion.version2.rawValue
        guard let url = Bundle.main.url(forResource: name, withExtension: "omo", subdirectory: modelDirectory)
                ?? Bundle.main.url(forResource: name, withExtension: "mom", subdirectory: modelDirectory),
              let model = NSManagedObjectModel(contentsOf: url)
        else { throw UserStorageMigrationError.unavailableModel(name) }
        return model
    }

    private static func validateStoreFiles(_ url: URL) throws {
        let manager = FileManager.default
        for path in [url.path, url.path + "-wal", url.path + "-shm", url.path + "-journal"] {
            guard manager.fileExists(atPath: path) else { continue }
            let attributes = try manager.attributesOfItem(atPath: path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  (attributes[.referenceCount] as? NSNumber)?.intValue == 1
            else { throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed }
        }
        if !manager.fileExists(atPath: url.path),
           ["-wal", "-shm", "-journal"].contains(where: { manager.fileExists(atPath: url.path + $0) }) {
            throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed
        }
    }

    private static func withContext<T>(storeURL: URL, model: NSManagedObjectModel, writable: Bool,
                                       body: (NSManagedObjectContext) throws -> T) throws -> T {
        try validateStoreFiles(storeURL)
        if FileManager.default.fileExists(atPath: storeURL.path) {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType, at: storeURL, options: [NSReadOnlyPersistentStoreOption: true])
            guard model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) else {
                throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed
            }
        }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        var options: [AnyHashable: Any] = [NSMigratePersistentStoresAutomaticallyOption: false,
                                          NSInferMappingModelAutomaticallyOption: false]
        if !writable {
            options[NSReadOnlyPersistentStoreOption] = true
            options[NSSQLitePragmasOption] = ["query_only": "ON"]
        }
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                                       at: storeURL, options: options)
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        var result: Result<T, Error>!
        context.performAndWait { result = Result { try body(context) } }
        return try result.get()
    }

    private static func accounts(in context: NSManagedObjectContext) throws -> [AccountItem] {
        let request = NSFetchRequest<CDAccountItem>(entityName: "CDAccountItem")
        request.fetchLimit = 2
        request.returnsObjectsAsFaults = false
        return try context.fetch(request).map { entity in
            guard (0...255).contains(Int(entity.cryptoType)), (0...255).contains(Int(entity.networkType)) else {
                throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed
            }
            return try AccountItemMapper().transform(entity: entity)
        }
    }

    private static func readAccounts(storeURL: URL, model: NSManagedObjectModel) throws -> [AccountItem] {
        try validateStoreFiles(storeURL)
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return [] }
        return try withContext(storeURL: storeURL, model: model, writable: false, body: accounts)
    }

    private static func insertFirstAccount(_ account: AccountItem, storeURL: URL,
                                            model: NSManagedObjectModel) throws {
        try withContext(storeURL: storeURL, model: model, writable: true) { context in
            guard try accounts(in: context).isEmpty else {
                throw WalletIntegrityError.legacyWalletUpgradeVerificationFailed
            }
            let entity = CDAccountItem(context: context)
            try AccountItemMapper().populate(entity: entity, from: account, using: context)
            try context.save()
        }
    }
}

final class RootInteractor {
    weak var presenter: RootInteractorOutputProtocol?

    var settings: SettingsManagerProtocol
    var keystore: KeystoreProtocol
    let migrators: [Migrating]
    var securityLayerInteractor: SecurityLayerInteractorInputProtocol
    var networkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol?
    private let legacyUpgradeLock = NSLock()
    private var didStartLegacyWalletUpgrade = false
    private let legacyUpgradeSelectedAccount: () -> AccountItem?
    private let legacyUpgradeSnapshotLoader:
        () throws -> WalletNetworkSnapshot?
    private let legacyUpgradeUnresolvedCommitLoader:
        () throws -> [WalletAccountCommitJournal]
    private let legacyUpgradeInteractorFactory:
        (
            KeystoreProtocol,
            SettingsManagerProtocol,
            Data,
            String
        ) -> AccountImportInteractorInputProtocol?

    init(settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         migrators: [Migrating],
         securityLayerInteractor: SecurityLayerInteractorInputProtocol,
         networkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol?,
         legacyUpgradeSelectedAccount:
             @escaping () -> AccountItem? = {
                 SelectedWalletSettings.shared.currentAccount
             },
         legacyUpgradeSnapshotLoader:
             @escaping () throws -> WalletNetworkSnapshot? = {
                 try WalletNetworkStore().load()
             },
         legacyUpgradeUnresolvedCommitLoader:
             @escaping () throws -> [WalletAccountCommitJournal] = {
                 try WalletAccountCommitJournalStore().unresolved()
             },
         legacyUpgradeInteractorFactory:
             @escaping (
                 KeystoreProtocol,
                 SettingsManagerProtocol,
                 Data,
                 String
             ) -> AccountImportInteractorInputProtocol? = {
                 keystore,
                 settings,
                 expectedEntropyDigest,
                 expectedDisplayName in
                 AccountImportViewFactory.createLegacyUpgradeInteractor(
                     keystore: keystore,
                     settings: settings,
                     expectedEntropyDigest: expectedEntropyDigest,
                     expectedDisplayName: expectedDisplayName
                 )
             }) {
        self.settings = settings
        self.keystore = keystore
        self.migrators = migrators
        self.securityLayerInteractor = securityLayerInteractor
        self.networkAvailabilityLayerInteractor = networkAvailabilityLayerInteractor
        self.legacyUpgradeSelectedAccount =
            legacyUpgradeSelectedAccount
        self.legacyUpgradeSnapshotLoader =
            legacyUpgradeSnapshotLoader
        self.legacyUpgradeUnresolvedCommitLoader =
            legacyUpgradeUnresolvedCommitLoader
        self.legacyUpgradeInteractorFactory =
            legacyUpgradeInteractorFactory
    }

    private func configureSecurityService() {
        securityLayerInteractor.setup()
    }

    private func configureDeepLinkService() {
        let invitationLinkService = InvitationLinkService(settings: settings)
        DeepLinkService.shared.setup(children: [invitationLinkService])
    }

    private func configureNetworkAvailabilityService() {
        networkAvailabilityLayerInteractor?.setup()
    }

    private func setupURLHandlingService() {
        let keystoreImportService = KeystoreImportService(logger: Logger.shared)

//        let callbackUrl = applicationConfig.purchaseRedirect
//        let purchaseHandler = PurchaseCompletionHandler(callbackUrl: callbackUrl,
//                                                        eventCenter: eventCenter)

        URLHandlingService.shared.setup(children: [/*purchaseHandler,*/ keystoreImportService])
    }

    var legacyImportInteractor: AccountImportInteractorInputProtocol?

    private func isLegacyWalletUpgradeCandidate(
        snapshot: WalletNetworkSnapshot?
    ) throws -> Bool {
        try LegacyWalletUpgradePolicy.isCandidate(
            keystore: keystore,
            hasWatchOnlyWallet:
                settings.hasRetainedWatchOnlyWallet(),
            snapshot: snapshot
        )
    }

    private func failLegacyWalletUpgrade(_ error: Error) {
        settings.setWalletMigrationRecovery(
            reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
        )
        legacyImportInteractor = nil
        presenter?.didDecideBroken()
    }

    private func verifyLegacyWalletUpgrade(
        account: AccountItem,
        expectedEntropyDigest: Data,
        expectedDisplayName: String
    ) throws {
        let scopedTags = [
            KeystoreTag.secretKeyTagForAddress(account.address),
            KeystoreTag.entropyTagForAddress(account.address),
            KeystoreTag.deriviationTagForAddress(account.address),
            KeystoreTag.seedTagForAddress(account.address),
        ]
        let identifiers = Set(try keystore.allKeyIdentifiers())
        var retainedEntropy = try keystore.fetchKey(
            for: KeystoreTag.legacyEntropy.rawValue
        )
        defer {
            retainedEntropy.resetBytes(
                in: retainedEntropy.startIndex ..<
                retainedEntropy.endIndex
            )
        }
        let mnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: retainedEntropy)
        try keystore.verifyLegacyIrohaKeyIfPresent(entropy: retainedEntropy)
        let wordCount = mnemonic.allWords().count
        guard
            let expectedSource = WalletMnemonicWordPolicy
                .retainedSecretSource(forWordCount: wordCount)
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }
        let expectedNetworks: Set<NetworkId> =
            expectedSource == .legacyMnemonicEntropy
                ? [.sora2]
                : NexusNetworkConfiguration.admittedWalletNetworkIds
        guard
            !retainedEntropy.isEmpty,
            Data(SHA256.hash(data: retainedEntropy)) ==
                expectedEntropyDigest,
            scopedTags.allSatisfy({ !identifiers.contains($0) }),
            let snapshot = try legacyUpgradeSnapshotLoader(),
            snapshot.wallets.count == 1,
            snapshot.selectedWalletId == account.address,
            snapshot.wallets.first?.id == account.address,
            snapshot.wallets.first?.existingSoraAddress ==
                account.address,
            account.username == expectedDisplayName,
            snapshot.wallets.first?.displayName == expectedDisplayName,
            snapshot.wallets.first?.secretSource == expectedSource,
            snapshot.accounts.filter({
                $0.walletId == account.address &&
                    $0.networkId == .sora2 &&
                    $0.address == account.address &&
                    $0.publicKey == account.publicKeyData
            }).count == 1,
            snapshot.accounts.allSatisfy({
                $0.walletId == account.address
            }),
            snapshot.accounts.count == expectedNetworks.count,
            Set(snapshot.accounts.map(\.networkId)) == expectedNetworks,
            try legacyUpgradeUnresolvedCommitLoader().isEmpty
        else {
            throw WalletIntegrityError
                .legacyWalletUpgradeVerificationFailed
        }
    }
}

extension RootInteractor: RootInteractorInputProtocol {
    func decideModuleSynchroniously() {
        do {
            if settings.walletMigrationRecoveryRequired {
                presenter?.didDecideBroken()
                return
            }

            let pincodeExists = try keystore.checkKey(
                for: KeystoreTag.pincode.rawValue
            )
            if legacyUpgradeSelectedAccount() == nil {
                let hasWatchOnlyWallet =
                    settings.hasRetainedWatchOnlyWallet()
                let networkSnapshot = try legacyUpgradeSnapshotLoader()
                let hasInventoriedWallets =
                    networkSnapshot?.wallets.isEmpty == false
                let hasRetainedWalletSettings =
                    settings.hasRetainedWalletSettings()
                if try isLegacyWalletUpgradeCandidate(
                    snapshot: networkSnapshot
                ) {
                    presenter?.didDecideLegacyWalletUpgrade()
                    return
                }
                let hasProtectedWalletMaterial =
                    try keystore.hasRetainedWalletMaterial()

                if hasProtectedWalletMaterial ||
                    hasRetainedWalletSettings ||
                    hasWatchOnlyWallet ||
                    hasInventoriedWallets ||
                    pincodeExists {
                    let error = WalletIntegrityError.selectedAccountMissing
                    settings.setWalletMigrationRecovery(
                        reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
                    )
                    presenter?.didDecideBroken()
                    return
                }

                presenter?.didDecideOnboarding()
                return
            }

            // Keep the legacy entropy record during this migration release.
            // The wallet model remains dual-readable for rollback/recovery and
            // a successful import is not permission to delete its source.

            if pincodeExists {
                presenter?.didDecideLocalAuthentication()
            } else {
                presenter?.didDecidePincodeSetup()
            }

        } catch {
            settings.setWalletMigrationRecovery(
                reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
            )
            presenter?.didDecideBroken()
        }
    }

    func performLegacyWalletUpgrade() {
        legacyUpgradeLock.lock()
        guard !didStartLegacyWalletUpgrade else {
            legacyUpgradeLock.unlock()
            return
        }
        didStartLegacyWalletUpgrade = true
        legacyUpgradeLock.unlock()

        do {
            guard
                !settings.walletMigrationRecoveryRequired,
                legacyUpgradeSelectedAccount() == nil,
                try isLegacyWalletUpgradeCandidate(
                    snapshot: legacyUpgradeSnapshotLoader()
                )
            else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }

            var legacyEntropy = try keystore.fetchKey(
                for: KeystoreTag.legacyEntropy.rawValue
            )
            defer {
                legacyEntropy.resetBytes(
                    in: legacyEntropy.startIndex ..<
                        legacyEntropy.endIndex
                )
            }
            guard !legacyEntropy.isEmpty else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }
            let expectedEntropyDigest = Data(
                SHA256.hash(data: legacyEntropy)
            )
            let mnemonic = try IRMnemonicCreator(
                language: .english
            ).mnemonic(fromEntropy: legacyEntropy)
            var phrase = mnemonic.toString()
            defer {
                phrase.removeAll(keepingCapacity: false)
            }
            let username = try LegacyWalletUpgradeDisplayNameResolver
                .resolve(
                    settings: settings,
                    keystore: keystore
                )
            guard
                WalletMnemonicWordPolicy.retainedSoraWordCounts
                    .contains(mnemonic.allWords().count),
                let importInteractor = legacyUpgradeInteractorFactory(
                    keystore,
                    settings,
                    expectedEntropyDigest,
                    username
                )
            else {
                throw WalletIntegrityError
                    .legacyWalletUpgradeVerificationFailed
            }

            let request = AccountImportMnemonicRequest(
                mnemonic: phrase,
                username: username,
                networkType: .sora,
                derivationPath: "",
                cryptoType: .sr25519
            )
            legacyImportInteractor = importInteractor
            importInteractor.importAccountWithMnemonic(
                request: request
            ) { [weak self] result in
                guard let self else {
                    return
                }
                switch result {
                case let .success(account):
                    do {
                        try self.verifyLegacyWalletUpgrade(
                            account: account,
                            expectedEntropyDigest:
                                expectedEntropyDigest,
                            expectedDisplayName: username
                        )
                        self.legacyImportInteractor = nil
                        self.decideModuleSynchroniously()
                    } catch {
                        self.failLegacyWalletUpgrade(error)
                    }
                case let .failure(error):
                    self.failLegacyWalletUpgrade(error)
                case .none:
                    self.failLegacyWalletUpgrade(
                        WalletIntegrityError
                            .legacyWalletUpgradeVerificationFailed
                    )
                }
            }
        } catch {
            failLegacyWalletUpgrade(error)
        }
    }

    private func runMigrators() {
        migrators.forEach { migrator in
            do {
                try migrator.migrate()
            } catch {
                let outcome = UserStorageMigrationError
                    .privacySafeOutcomeCode(for: error)
                Logger.shared.error(
                    "Wallet migrator outcome: \(outcome)"
                )
            }
        }
    }

    func setup() {
        setupURLHandlingService()
        configureSecurityService()
        configureNetworkAvailabilityService()
        configureDeepLinkService()
        runMigrators()

    }
}
