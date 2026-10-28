// Copyright (c) 2026, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import CryptoKit
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFUtils

/// Explicit repair is the only writer allowed to replace a failed scoped key.
/// Originals, intent and completed receipt all live in device-only Keychain.
/// Nothing in this service erases a quarantine record or trusts a defaults flag.
final class WalletCredentialRepair {
    static let pendingTag = "wallet-credential-repair-pending-v1"
    static let quarantinePrefix = "wallet-credential-quarantine-v1-"
    static let receiptPrefix = "wallet-credential-repair-receipt-v1-"

    static func requireNoPendingRepair(keystore: KeystoreProtocol = Keychain()) throws {
        guard try !keystore.checkKey(for: pendingTag) else { throw Failure.persistenceFailed }
    }

    enum Failure: LocalizedError, Equatable {
        case confirmationRequired, suppliedMaterialRequired, accountChanged
        case watchOnly, invalidJournal, persistenceFailed, retainedMaterialChanged
        var errorDescription: String? {
            switch self {
            case .confirmationRequired:
                return WalletUX.text("Confirm the repair before changing this wallet's credentials.")
            case .suppliedMaterialRequired:
                return WalletUX.text("Enter the recovery phrase, raw seed, or JSON backup that restores this exact wallet address.")
            case .accountChanged, .watchOnly:
                return WalletUX.text("This wallet cannot be repaired in its current state. Return to recovery and try again.")
            case .invalidJournal, .persistenceFailed, .retainedMaterialChanged:
                return WalletUX.text("The repair could not be completed. Preserved credentials remain on this iPhone. Retry the repair before using this wallet.")
            }
        }
    }

    struct Material {
        var secret: Data
        var entropy: Data?
        var seed: Data?
        var derivation: Data?
        mutating func wipe() {
            secret.resetBytes(in: 0..<secret.count)
            if let count = entropy?.count { entropy?.resetBytes(in: 0..<count) }
            if let count = seed?.count { seed?.resetBytes(in: 0..<count) }
            if let count = derivation?.count { derivation?.resetBytes(in: 0..<count) }
        }
    }

    enum Result: Equatable { case supplemented, repaired }
    enum ImportAuthentication {
        case currentPIN(String)
        case newPIN(String, confirmation: String)
    }

    /// Ephemeral proof that this exact first wallet just completed explicit
    /// new-PIN setup. Never serialized, and never reconstructed from Keychain.
    final class InitialPINCompletion {
        private let account: AccountItem
        private let pinDigest: Data
        fileprivate init(account: AccountItem, pin: String) {
            self.account = account
            pinDigest = Data(SHA256.hash(data: Data(pin.utf8)))
        }
        func validate(account: AccountItem, currentAccounts: [AccountItem],
                      keystore: KeystoreProtocol, settings: SettingsManagerProtocol,
                      recoveryGate: WalletRecoveryCapabilityGate) throws {
            guard currentAccounts.isEmpty, WalletCredentialRepair.sameIdentity(self.account, account),
                  let pin = try keystore.loadIfKeyExists(KeystoreTag.pincode.rawValue),
                  Data(SHA256.hash(data: pin)) == pinDigest,
                  let text = String(data: pin, encoding: .utf8),
                  let bytes = try keystore.loadIfKeyExists(account.address + WalletOwnerPIN.bindingSuffix),
                  let binding = try? JSONDecoder().decode(WalletOwnerPIN.Binding.self, from: bytes),
                  try binding.matches(text),
                  try !WalletOwnerPIN(keystore: keystore, settings: settings, recoveryGate: recoveryGate)
                    .requiresInitialSetup(accounts: [account]) else { throw Failure.accountChanged }
        }
    }
    enum Source: Int { case phrase, seed, json }
    private enum Role: String, Codable, CaseIterable {
        case derivation, entropy, seed, secret, binding
        func tag(_ address: String) -> String {
            switch self {
            case .derivation: return KeystoreTag.deriviationTagForAddress(address)
            case .entropy: return KeystoreTag.entropyTagForAddress(address)
            case .seed: return KeystoreTag.seedTagForAddress(address)
            case .secret: return KeystoreTag.secretKeyTagForAddress(address)
            case .binding: return address + WalletOwnerPIN.bindingSuffix
            }
        }
    }
    private struct Change: Codable {
        let role: Role
        let original: Data?
        let replacement: Data?
    }
    private struct Intent: Codable {
        let version: Int
        let id: UUID
        let account: AccountItem
        let pinDigest: Data
        let changes: [Change]
    }

    private let keystore: KeystoreProtocol
    private let settings: SettingsManagerProtocol
    private let recoveryGate: WalletRecoveryCapabilityGate
    private let lifecycleCoordinator: WalletLifecycleCoordinator
    private let activeSnapshot: () throws -> WalletNetworkSnapshot?

    init(keystore: KeystoreProtocol, settings: SettingsManagerProtocol,
         recoveryGate: WalletRecoveryCapabilityGate = .shared,
         lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
         activeSnapshot: (() throws -> WalletNetworkSnapshot?)? = nil) {
        self.keystore = keystore
        self.settings = settings
        self.recoveryGate = recoveryGate
        self.lifecycleCoordinator = lifecycleCoordinator
        self.activeSnapshot = activeSnapshot ?? { try WalletNetworkStore(recoveryGate: recoveryGate).load() }
    }

    static func sameIdentity(_ first: AccountItem, _ second: AccountItem) -> Bool {
        first.address == second.address && first.publicKeyData == second.publicKeyData &&
            first.cryptoType == second.cryptoType && first.networkType == second.networkType
    }

    func hasPendingRepair() throws -> Bool { try keystore.checkKey(for: Self.pendingTag) }

    /// A freshly decrypted, identity-checked backup is supplied material; this
    /// constructor still performs PreparedAccount's production signing proof.
    func prepareDirectSecret(account: AccountItem, secret: Data) throws -> PreparedAccount {
        try PreparedAccount(account: account, secretKey: secret, entropy: nil,
            seed: nil, derivationPath: nil, recoveryGate: recoveryGate, suppliedOwnershipProof: true)
    }

    func retryPending(account: AccountItem, currentAccounts: () throws -> [AccountItem]) throws {
        let lease = lifecycleCoordinator.acquire()
        defer { lease.release() }
        guard let bytes = try keystore.loadIfKeyExists(Self.pendingTag), bytes.count <= 8 * 1024 * 1024,
              let intent = try? JSONDecoder().decode(Intent.self, from: bytes),
              Self.sameIdentity(account, intent.account) else { throw Failure.accountChanged }
        let accounts = try currentAccounts()
        try resumePending(accounts: accounts)
        guard accounts.contains(where: { Self.sameIdentity($0, account) }) else { throw Failure.accountChanged }
    }

    /// Pure preparation for the recovery UI. The known account fixes both the
    /// crypto type and address, including historical short phrases. No writes.
    func prepare(account: AccountItem, source: Source, text: String,
                 derivationPath: String, backupPassword: String) throws -> PreparedAccount {
        guard text.utf8.count <= 1024 * 1024, derivationPath.utf8.count <= 4096,
              backupPassword.utf8.count <= 4096 else { throw Failure.suppliedMaterialRequired }
        if source == .json {
            var secret = try WalletCloudBackupRecoveryService.extractJSONSecret(text,
                password: backupPassword, account: account)
            defer { secret.resetBytes(in: 0..<secret.count) }
            return try prepareDirectSecret(account: account, secret: secret)
        }
        let factory = AccountOperationFactory(keystore: keystore, recoveryGate: recoveryGate)
        let operation: BaseOperation<PreparedAccount>
        if source == .phrase {
            let words = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: words)
            guard let count = Int(exactly: mnemonic.numberOfWords()),
                  WalletMnemonicWordPolicy.knownAddressRestoreWordCounts.contains(count) else {
                throw Failure.suppliedMaterialRequired
            }
            operation = factory.prepareAccountOperation(request: AccountCreationRequest(username: account.username,
                type: .sora, derivationPath: derivationPath, cryptoType: account.cryptoType), mnemonic: mnemonic)
        } else {
            // Reject bad lengths before any native seed/key factory call.
            let seed = try Data(hexStringSSF: text.trimmingCharacters(in: .whitespacesAndNewlines))
            guard seed.count == 32 || seed.count == 64 else { throw Failure.suppliedMaterialRequired }
            operation = factory.prepareAccountOperation(request: AccountImportSeedRequest(seed: text.trimmingCharacters(in: .whitespacesAndNewlines),
                username: account.username, networkType: .sora, derivationPath: derivationPath,
                cryptoType: account.cryptoType))
        }
        operation.start()
        let prepared = try operation.extractNoCancellableResultData()
        guard Self.sameIdentity(account, prepared.account) else {
            prepared.discard()
            throw Failure.suppliedMaterialRequired
        }
        return prepared
    }

    /// Fresh supplied material is the only authority to recover an absent row.
    /// An existing install requires its manually entered PIN. Empty onboarding
    /// requires an explicitly chosen and repeated NEW PIN, never the retained PIN.
    /// The lease spans quarantine, PIN publication and normal journaled insertion.
    /// Call off main; completion runs on the insertion operation's queue.
    func importMissingAccount(prepared: PreparedAccount,
                              currentAccounts: () throws -> [AccountItem],
                              authentication: ImportAuthentication,
                              explicitlyConfirmed: Bool,
                              selection: SelectedWalletSettingsProtocol,
                              completion: @escaping (Swift.Result<AccountItem, Error>) -> Void) {
        let lease = lifecycleCoordinator.acquire()
        do {
            guard explicitlyConfirmed else { throw Failure.confirmationRequired }
            var supplied = try prepared.credentialRepairMaterial()
            defer { supplied.wipe() }
            try recoveryGate.requireCredentialRepairAccess()
            let accounts = try currentAccounts()
            guard Set(accounts.map(\.address)).count == accounts.count,
                  !accounts.contains(where: { $0.address == prepared.account.address }) else {
                throw Failure.accountChanged
            }
            try resumePending(accounts: accounts)
            try requireNotWatchOnly(prepared.account)
            try validate(supplied, for: prepared.account)
            let owner = WalletOwnerPIN(keystore: keystore, settings: settings, recoveryGate: recoveryGate)
            try owner.recoverRotation()
            try owner.settleRebindings(currentAddresses: Set(accounts.map(\.address)))
            let pin: String
            let creatingPIN: Bool
            switch authentication {
            case .currentPIN(let entered):
                guard !accounts.isEmpty, try !owner.requiresInitialSetup(accounts: accounts) else {
                    throw WalletOwnerPIN.Failure.authenticationRequired
                }
                _ = try owner.authenticateCurrent(entered, accounts: [])
                pin = entered; creatingPIN = false
            case .newPIN(let entered, let confirmation):
                guard accounts.isEmpty else { throw Failure.accountChanged }
                guard entered == confirmation, [4, 6].contains(entered.utf8.count),
                      entered.utf8.allSatisfy({ (48...57).contains($0) }) else {
                    throw WalletOwnerPIN.Failure.invalidPIN
                }
                pin = entered; creatingPIN = true
            }
            // Capture a separate fresh prepared object before add-only persistence
            // consumes the caller's object. Only this object reaches insertion.
            let insertion = try PreparedAccount(account: prepared.account, secretKey: supplied.secret,
                entropy: supplied.entropy, seed: supplied.seed,
                derivationPath: supplied.derivation.flatMap { String(data: $0, encoding: .utf8) },
                recoveryGate: recoveryGate, suppliedOwnershipProof: true)
            if creatingPIN {
                try owner.prepareInitialSetup(account: prepared.account, operationID: UUID())
            }
            if let retained = try keystore.loadIfKeyExists(Role.secret.tag(prepared.account.address)),
               try proves(retained, account: prepared.account) {
                try prepared.persist(to: keystore)
            } else {
                try quarantineAndRepair(supplied: supplied, account: prepared.account, accounts: accounts,
                    pin: pin, authorizedMissingAccount: prepared.account,
                    initialPIN: creatingPIN ? pin : nil)
                prepared.discard()
            }
            if creatingPIN {
                // setInitialPIN itself journals and reads back both the PIN and
                // exact proved wallet binding, consuming only its setup intent.
                try owner.setInitialPIN(pin, accounts: [insertion.account])
                insertion.completedInitialPINSetup = InitialPINCompletion(account: insertion.account, pin: pin)
            }
            selection.performInsertAndSelect(prepared: insertion,
                persistSecrets: { try insertion.persist(to: self.keystore) }, lifecycleLease: lease) { result in
                    lease.release()
                    completion(result)
                }
        } catch {
            lease.release()
            completion(.failure(error))
        }
    }

    /// Called off main. The exact row is read after the lifecycle lease is held.
    /// The typed PIN is checked here even if the caller was unlocked biometrically.
    func repair(prepared: PreparedAccount, currentAccounts: () throws -> [AccountItem],
                pin: String, explicitlyConfirmed: Bool) throws -> Result {
        guard explicitlyConfirmed else { throw Failure.confirmationRequired }
        var supplied = try prepared.credentialRepairMaterial()
        defer { supplied.wipe() }
        let lease = lifecycleCoordinator.acquire()
        defer { lease.release() }
        try recoveryGate.requireCredentialRepairAccess()
        let accounts = try currentAccounts()
        try resumePending(accounts: accounts)
        guard let existing = accounts.first(where: { Self.sameIdentity($0, prepared.account) }),
              accounts.filter({ $0.address == existing.address }).count == 1 else {
            throw Failure.accountChanged
        }
        try requireNotWatchOnly(existing)
        let owner = WalletOwnerPIN(keystore: keystore, settings: settings, recoveryGate: recoveryGate)
        try owner.recoverRotation()
        guard try !owner.requiresInitialSetup(accounts: accounts) else {
            throw WalletOwnerPIN.Failure.authenticationRequired
        }
        try owner.settleRebindings(currentAddresses: Set(accounts.map(\.address)))
        // Empty reconciliation set: the failed key must not be bound merely
        // because its database row exists. Binding is part of our proven intent.
        _ = try owner.authenticateCurrent(pin, accounts: [])
        try validate(supplied, for: existing)

        if let retained = try keystore.loadIfKeyExists(Role.secret.tag(existing.address)),
           try proves(retained, account: existing) {
            // A working direct key is strictly add-only, including nonce bytes
            // and malformed redundant ed25519 public halves accepted by 3.8.6.
            try prepared.persist(to: keystore)
            try owner.prepareRebinding(address: existing.address, to: pin, consumeSetupIntent: true)
            try owner.settleRebindings(currentAddresses: Set(accounts.map(\.address)))
            return .supplemented
        }

        try quarantineAndRepair(supplied: supplied, account: existing, accounts: accounts, pin: pin)
        prepared.discard()
        return .repaired
    }

    private func quarantineAndRepair(supplied: Material, account: AccountItem, accounts: [AccountItem],
                                     pin: String, authorizedMissingAccount: AccountItem? = nil,
                                     initialPIN: String? = nil) throws {
        var originals: [Role: Data] = [:]
        for role in Role.allCases {
            if let bytes = try keystore.loadIfKeyExists(role.tag(account.address)) {
                guard bytes.count <= 1024 * 1024 else { throw Failure.invalidJournal }
                originals[role] = bytes
            }
        }
        var target = try targetMaterial(supplied, originals: originals, account: account)
        target[.binding] = try JSONEncoder().encode(WalletOwnerPIN.Binding(pin: pin))
        let intent = Intent(version: 1, id: UUID(), account: account,
            pinDigest: Data(SHA256.hash(data: Data(pin.utf8))),
            changes: Role.allCases.map { Change(role: $0, original: originals[$0], replacement: target[$0]) })
        guard try !keystore.checkKey(for: Self.pendingTag) else { throw Failure.invalidJournal }
        try addVerified(try JSONEncoder().encode(intent), tag: Self.pendingTag)
        try resumePending(accounts: accounts, authorizedMissingAccount: authorizedMissingAccount, initialPIN: initialPIN)
    }

    /// Caller must hold a lifecycle lease. Run before all authentication and
    /// startup availability checks. A missing row archives the entire intent
    /// without changing credentials; a replaced identity fails closed. Archived
    /// receipts never grant authority over a new installation's rows.
    func resumePending(accounts: [AccountItem]) throws {
        try resumePending(accounts: accounts, authorizedMissingAccount: nil, initialPIN: nil)
    }

    /// Only the current explicit import invocation may supply a missing identity.
    /// No persisted field grants this exception on startup or on a later retry.
    private func resumePending(accounts: [AccountItem], authorizedMissingAccount: AccountItem?,
                               initialPIN: String?) throws {
        guard let bytes = try keystore.loadIfKeyExists(Self.pendingTag) else { return }
        try recoveryGate.requireCredentialRepairAccess()
        guard bytes.count <= 8 * 1024 * 1024,
              let intent = try? JSONDecoder().decode(Intent.self, from: bytes), intent.version == 1,
              intent.pinDigest.count == 32, intent.changes.count == Role.allCases.count,
              Set(intent.changes.map(\.role)) == Set(Role.allCases) else {
            throw Failure.invalidJournal
        }
        let current = accounts.filter { $0.address == intent.account.address }
        let authorizedMissing = current.isEmpty && authorizedMissingAccount.map {
            Self.sameIdentity($0, intent.account)
        } == true
        if current.isEmpty && !authorizedMissing {
            // Uninstall can erase rows while this Keychain intent survives.
            // Its self-contained original AND intended bytes are archived before
            // retiring only the active marker. No key, binding or ownership is
            // adopted; subsequent recovery must supply its own proof as usual.
            let archive = Self.receiptPrefix + "orphaned-" + intent.id.uuidString
            if let recorded = try keystore.loadIfKeyExists(archive) {
                guard recorded == bytes else { throw Failure.retainedMaterialChanged }
            } else { try addVerified(bytes, tag: archive) }
            try keystore.deleteKey(for: Self.pendingTag)
            guard try !keystore.checkKey(for: Self.pendingTag) else { throw Failure.persistenceFailed }
            return
        }
        guard authorizedMissing || (current.count == 1 && Self.sameIdentity(current[0], intent.account)) else {
            throw Failure.accountChanged
        }
        try requireNotWatchOnly(intent.account)
        // The new PIN is available only in this fresh, explicitly confirmed
        // empty-install invocation. Automatic resume always checks the app PIN.
        guard initialPIN == nil || (authorizedMissing && accounts.isEmpty) else { throw Failure.invalidJournal }
        var pin = try initialPIN.map { Data($0.utf8) } ?? keystore.fetchKey(for: KeystoreTag.pincode.rawValue)
        defer { pin.resetBytes(in: 0..<pin.count) }
        guard Data(SHA256.hash(data: pin)) == intent.pinDigest else {
            throw WalletOwnerPIN.Failure.authenticationRequired
        }
        let changes = Dictionary(uniqueKeysWithValues: intent.changes.map { ($0.role, $0) })
        guard let secret = changes[.secret]?.replacement,
              let bindingData = changes[.binding]?.replacement,
              let binding = try? JSONDecoder().decode(WalletOwnerPIN.Binding.self, from: bindingData),
              let pinString = String(data: pin, encoding: .utf8), try binding.matches(pinString) else {
            throw Failure.invalidJournal
        }
        var target = Material(secret: secret, entropy: changes[.entropy]?.replacement,
                              seed: changes[.seed]?.replacement, derivation: changes[.derivation]?.replacement)
        defer { target.wipe() }
        try validate(target, for: intent.account)
        if let original = changes[.secret]?.original, try proves(original, account: intent.account) {
            throw Failure.invalidJournal
        }

        // Validate the complete source/target set before the first mutation.
        // A legacy app or another writer changing a third value cannot be
        // silently overwritten by an old transaction.
        for change in intent.changes {
            let live = try keystore.loadIfKeyExists(change.role.tag(intent.account.address))
            guard live == change.original || live == change.replacement else {
                throw Failure.retainedMaterialChanged
            }
        }
        // Every replaced original is preserved and read back before any live
        // credential is changed, even when the next write is interrupted.
        for change in intent.changes where change.original != change.replacement {
            if let original = change.original {
                let tag = Self.quarantinePrefix + intent.id.uuidString + "-" + change.role.rawValue
                if let preserved = try keystore.loadIfKeyExists(tag) {
                    guard preserved == original else { throw Failure.retainedMaterialChanged }
                } else { try addVerified(original, tag: tag) }
            }
        }
        for change in intent.changes {
            try recoveryGate.requireCredentialRepairAccess()
            let tag = change.role.tag(intent.account.address)
            if try keystore.loadIfKeyExists(tag) == change.replacement { continue }
            if let replacement = change.replacement {
                try keystore.saveKey(replacement, with: tag)
            } else { try keystore.deleteKeyIfExists(for: tag) }
            guard try keystore.loadIfKeyExists(tag) == change.replacement else { throw Failure.persistenceFailed }
        }
        guard let live = try keystore.fetchSecretKeyForAddress(intent.account.address),
              try proves(live, account: intent.account) else { throw Failure.persistenceFailed }
        let receipt = Self.receiptPrefix + intent.id.uuidString
        if let recorded = try keystore.loadIfKeyExists(receipt) {
            guard recorded == bytes else { throw Failure.retainedMaterialChanged }
        } else { try addVerified(bytes, tag: receipt) }
        try keystore.deleteKey(for: Self.pendingTag)
        guard try !keystore.checkKey(for: Self.pendingTag) else { throw Failure.persistenceFailed }
    }

    private func requireNotWatchOnly(_ account: AccountItem) throws {
        guard !settings.allKeys().contains("wallet.watchOnly.\(account.address)") else { throw Failure.watchOnly }
        guard try activeSnapshot()?.wallets.first(where: { $0.id == account.address })?.secretSource != .watchOnly else {
            throw Failure.watchOnly
        }
    }

    private func addVerified(_ bytes: Data, tag: String) throws {
        try keystore.addKey(bytes, with: tag)
        guard try keystore.fetchKey(for: tag) == bytes else { throw Failure.persistenceFailed }
    }

    private func proves(_ secret: Data, account: AccountItem) throws -> Bool {
        do {
            try LegacySoraIdentityValidator.validateSigningSecret(address: account.address,
                publicKey: account.publicKeyData, cryptoType: account.cryptoType,
                networkType: account.networkType, secret: secret, recoveryGate: recoveryGate)
            return true
        } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) { return false }
    }

    private func validate(_ material: Material, for account: AccountItem) throws {
        let path: String?
        if let bytes = material.derivation {
            guard bytes.count <= 4096, let value = String(data: bytes, encoding: .utf8) else { throw Failure.invalidJournal }
            path = value
        } else { path = nil }
        try LegacySoraIdentityValidator.validate(address: account.address, publicKey: account.publicKeyData,
            cryptoType: account.cryptoType, networkType: account.networkType, derivationPath: path,
            entropy: material.entropy, rawSeed: material.seed, secret: material.secret, recoveryGate: recoveryGate)
    }

    private func targetMaterial(_ supplied: Material, originals: [Role: Data], account: AccountItem) throws -> [Role: Data] {
        var result: [Role: Data] = [.secret: supplied.secret]
        result[.entropy] = supplied.entropy
        result[.seed] = supplied.seed
        result[.derivation] = supplied.derivation
        // JSON has no path/backup sources. Keep independently proven old
        // auxiliaries; malformed or non-matching items move to quarantine.
        let jsonOnly = supplied.entropy == nil && supplied.seed == nil
        let pathBytes = jsonOnly ? originals[.derivation] : supplied.derivation
        let path = pathBytes.flatMap { String(data: $0, encoding: .utf8) }
        if pathBytes == nil || path != nil {
            var oldBackup = try WalletBackupMaterial.assess(for: account, recoveryGate: recoveryGate,
                readEntropy: { originals[.entropy] }, readSeed: { originals[.seed] }, readPath: { path })
            defer { oldBackup.wipe() }
            if oldBackup.phraseStatus == .matching { result[.entropy] = oldBackup.entropy }
            if oldBackup.seedStatus == .matching { result[.seed] = oldBackup.seed }
            if jsonOnly, result[.entropy] != nil || result[.seed] != nil { result[.derivation] = pathBytes }
        }
        return result
    }
}
