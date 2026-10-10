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
import RobinHood
import SoraKeystore
import SSFCrypto
import SSFUtils

// MARK: - Interrupted ordinary create or import

/// Resolves an ordinary create or import that was interrupted between its
/// journal's `begin` and `activated` (not the first activation of the
/// original unsuffixed legacy entropy, which `LegacyWalletAccountCommitRecovery`
/// owns).
///
/// - The account row reached Core Data: the network model is rebuilt from the
///   database (which proves every account, read-only ones included), the
///   selection is written to the legacy setting, and the journal is advanced
///   to `activated`.
/// - The account row never reached Core Data: the journal becomes `abandoned`.
///
/// Key material is never written or deleted. Items an abandoned import wrote
/// stay in the Keychain; a later import of the same phrase adopts them.
enum OrdinaryWalletAccountCommitRecovery {
    enum Outcome: Equatable {
        case rolledForward(walletId: String)
        case abandoned(walletId: String)
    }

    enum Failure: Error {
        /// The journal says the account reached Core Data, but it is not there.
        case committedAccountMissing
    }

    /// True when the journals describe the first activation backed by the
    /// unsuffixed legacy `seedEntropy`: exactly one journal, no other wallet,
    /// a legacy-only Keychain, and the retained entropy derives the journal's
    /// address. Unreadable Keychain state keeps the legacy resolver (which
    /// fails closed and is retried).
    static func isLegacyFirstActivation(
        journals: [WalletAccountCommitJournal],
        candidates: [WalletAccountCommitJournal],
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol
    ) -> Bool {
        guard journals.count == 1, candidates.count == 1,
              candidates[0].expectedExistingWalletIds.isEmpty else {
            return false
        }
        do {
            guard try LegacyWalletUpgradePolicy.isCandidate(
                keyIdentifiers: Set(keystore.allKeyIdentifiers()),
                hasWatchOnlyWallet: settings.hasRetainedWatchOnlyWallet(),
                snapshot: nil,
                legacyIrohaKeyVerified: true
            ) else {
                return false
            }
            var entropy = try keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue)
            defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
            guard WalletMnemonicWordPolicy.isDerivableEntropy(entropy) else { return false }
            var phrase = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy).toString()
            defer { phrase.removeAll(keepingCapacity: false) }
            var seed = try SeedFactory().deriveSeed(from: phrase, password: "").seed.miniSeed
            defer { seed.resetBytes(in: seed.startIndex ..< seed.endIndex) }
            let keypair = try SR25519KeypairFactory().createKeypairFromSeed(seed, chaincodeList: [])
            let address = try SS58AddressFactory().address(
                fromAccountId: keypair.publicKey().rawData(),
                type: SNAddressType(chain: .sora)
            )
            return address == candidates[0].walletId
        } catch {
            return true
        }
    }

    /// Resolves every unresolved journal. The caller holds the lifecycle lease
    /// and supplies a journal store and network store bound to its marker.
    @discardableResult
    static func resolve(
        journals: [WalletAccountCommitJournal],
        storeURL: URL,
        modelDirectory: String,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        journalStore: WalletAccountCommitJournalStore,
        networkStore: WalletNetworkStore,
        recoveryGate: WalletRecoveryCapabilityGate
    ) throws -> [Outcome] {
        var outcomes: [Outcome] = []
        for journal in journals.filter({ !$0.stage.isTerminal })
            .sorted(by: { $0.createdAt < $1.createdAt }) {
            try recoveryGate.requireAuthorizedLifecycleContinuation()
            let accounts = try LegacyWalletAccountCommitRecovery.readAllAccounts(
                storeURL: storeURL,
                modelDirectory: modelDirectory
            )
            guard accounts.contains(where: { $0.address == journal.walletId }) else {
                guard [.prepared, .secretsPersisted].contains(journal.stage) else {
                    throw Failure.committedAccountMissing
                }
                _ = try journalStore.advance(journal, to: .abandoned)
                Logger.shared.info("Wallet account commit: interrupted import set aside")
                outcomes.append(.abandoned(walletId: journal.walletId))
                continue
            }

            let legacySelectedAddress = settings.value(
                of: AccountItem.self,
                for: SettingsKey.selectedAccount.rawValue
            )?.identifier
            guard let selected = try SelectedWalletSettings.resolveSelection(
                accounts: accounts,
                legacySelectedAddress: legacySelectedAddress
            ) else {
                throw SelectedWalletSettingsError.missingSelectedAccount
            }
            // Proves every account (read-only ones stay read-only) and
            // publishes the snapshot. No Keychain item is written.
            try WalletNetworkModelMigrator(
                keystore: keystore,
                store: networkStore,
                settings: settings,
                lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: recoveryGate),
                recoveryGate: recoveryGate
            ).migrate(accounts: accounts, selectedAddress: selected.address)
            try recoveryGate.requireAuthorizedLifecycleContinuation()
            if settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue) != selected {
                settings.set(value: selected, for: SettingsKey.selectedAccount.rawValue)
                guard settings.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue) == selected else {
                    throw WalletNetworkMigrationError.snapshotVerificationFailed
                }
            }
            let order: [WalletAccountCommitStage] = [
                .prepared, .secretsPersisted, .coreDataCommitted, .networkModelActivated, .activated,
            ]
            var current = journal
            if let start = order.firstIndex(of: current.stage) {
                for stage in order.suffix(from: start + 1) {
                    current = try journalStore.advance(current, to: stage)
                }
            }
            Logger.shared.info("Wallet account commit: interrupted import completed")
            outcomes.append(.rolledForward(walletId: journal.walletId))
        }
        return outcomes
    }
}

// MARK: - Scoped copies (downgrade safety)

/// Derives the scoped items released writers stored for an account
/// (2.x and App Store 3.8.6 `AccountOperationFactory`): a phrase gives the
/// mini seed (with the path's password), and the seed gives the secret
/// through the path's junctions. Pure; nothing is read or written.
enum WalletScopedKeyDerivation {
    struct Material {
        /// The mini seed derived from a phrase, or the stored raw seed.
        var seed: Data
        var secret: Data

        mutating func wipe() {
            seed.resetBytes(in: seed.startIndex ..< seed.endIndex)
            secret.resetBytes(in: secret.startIndex ..< secret.endIndex)
        }
    }

    /// Returns nil when there is nothing to derive from: no phrase entropy
    /// the mnemonic library can expand (3/6/9-word entropy cannot be) and no
    /// raw seed.
    static func derive(
        cryptoType: CryptoType,
        derivationPath: String?,
        entropy: Data?,
        rawSeed: Data?
    ) throws -> Material? {
        let path = derivationPath ?? ""
        let junction = path.isEmpty ? nil : try SubstrateJunctionFactory().parse(path: path)
        let chaincodes = junction?.chaincodes ?? []
        var seed: Data
        if let entropy, WalletMnemonicWordPolicy.isDerivableEntropy(entropy) {
            var phrase = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy).toString()
            defer { phrase.removeAll(keepingCapacity: false) }
            seed = try SeedFactory().deriveSeed(from: phrase, password: junction?.password ?? "").seed.miniSeed
        } else if let rawSeed, !rawSeed.isEmpty {
            seed = rawSeed
        } else {
            return nil
        }
        let secret: Data
        switch cryptoType {
        case .sr25519:
            secret = try SR25519KeypairFactory().createKeypairFromSeed(seed, chaincodeList: chaincodes)
                .privateKey().rawData()
        case .ed25519:
            secret = try Ed25519KeypairFactory().deriveChildSeedFromParent(seed.miniSeed, chaincodeList: chaincodes)
        case .ecdsa:
            secret = try EcdsaKeypairFactory().deriveChildSeedFromParent(seed.miniSeed, chaincodeList: chaincodes)
        }
        return Material(seed: seed, secret: secret)
    }
}

/// Adds the missing `<address>-seed` and `<address>-secretKey` items of an
/// account whose own scoped phrase or seed proves it.
///
/// App Store 3.8.6 signs only with `-secretKey` and wipes its settings when
/// the selected account has none. Accounts restored by phrase or seed in
/// 3.9.0, and writes interrupted by a kill, can lack it. Rules:
/// - add-only (`addKey`), never update or delete;
/// - the stored items and the derived ones must prove the account (address,
///   public key and a signature) before anything is written;
/// - the seed is written before the secret, and each write is read back;
/// - an existing item that differs stops without writing.
enum WalletScopedKeyCompletion {
    enum Outcome: Equatable {
        /// `-secretKey` already exists; nothing to add.
        case complete
        /// These tags were added, in this order.
        case added([String])
        /// No scoped phrase or seed to derive from (for example a secret-only
        /// or a global-only account, or no keys at all).
        case nothingToDeriveFrom
        /// The stored items do not prove the account, or an existing item
        /// differs. Nothing was written.
        case conflict
    }

    static func addMissingCopies(
        for account: AccountItem,
        keystore: KeystoreProtocol,
        recoveryGate: WalletRecoveryCapabilityGate
    ) throws -> Outcome {
        let address = account.address
        let secretTag = KeystoreTag.secretKeyTagForAddress(address)
        let seedTag = KeystoreTag.seedTagForAddress(address)
        guard try !keystore.checkKey(for: secretTag) else { return .complete }
        var storedEntropy = try keystore.loadIfKeyExists(KeystoreTag.entropyTagForAddress(address))
        var storedSeed = try keystore.loadIfKeyExists(seedTag)
        defer {
            if let count = storedEntropy?.count { storedEntropy?.resetBytes(in: 0 ..< count) }
            if let count = storedSeed?.count { storedSeed?.resetBytes(in: 0 ..< count) }
        }
        let derivationPath = try keystore.fetchDeriviationForAddress(address)
        let derivable = storedEntropy.map(WalletMnemonicWordPolicy.isDerivableEntropy) == true
        guard var derived = try WalletScopedKeyDerivation.derive(
            cryptoType: account.cryptoType,
            derivationPath: derivationPath,
            entropy: storedEntropy,
            rawSeed: storedSeed
        ) else {
            return .nothingToDeriveFrom
        }
        defer { derived.wipe() }
        do {
            try LegacySoraIdentityValidator.validate(
                address: address,
                publicKey: account.publicKeyData,
                cryptoType: account.cryptoType,
                networkType: account.networkType,
                derivationPath: derivationPath,
                entropy: storedEntropy,
                rawSeed: storedSeed ?? (derivable ? derived.seed : nil),
                secret: derived.secret,
                recoveryGate: recoveryGate
            )
        } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
            return .conflict
        }

        var plan: [(String, Data, Bool)] = []
        if storedSeed == nil, derivable {
            plan.append((seedTag, derived.seed, false))
        }
        plan.append((secretTag, derived.secret, true))
        var added: [String] = []
        for (tag, value, isSecret) in plan {
            try recoveryGate.requireAuthorizedLifecycleContinuation()
            switch try WalletScopedKeyWrite.addIfAbsent(
                value, tag: tag, isSecret: isSecret, cryptoType: account.cryptoType, keystore: keystore
            ) {
            case .added: added.append(tag)
            case .alreadyMatching: continue
            case .differs: return added.isEmpty ? .conflict : .added(added)
            }
        }
        return added.isEmpty ? .complete : .added(added)
    }
}

/// One add-only write, read back.
enum WalletScopedKeyWrite {
    enum Outcome {
        case added
        case alreadyMatching
        case differs
    }

    static func addIfAbsent(
        _ value: Data,
        tag: String,
        isSecret: Bool,
        cryptoType: CryptoType,
        keystore: KeystoreProtocol
    ) throws -> Outcome {
        if try keystore.checkKey(for: tag) {
            var existing = try keystore.fetchKey(for: tag)
            defer { existing.resetBytes(in: existing.startIndex ..< existing.endIndex) }
            let matches = isSecret
                ? LegacySoraIdentityValidator.storedSecret(existing, matches: value, cryptoType: cryptoType)
                : LegacySoraIdentityValidator.constantTimeEqual(existing, value)
            return matches ? .alreadyMatching : .differs
        }
        try keystore.addKey(value, with: tag)
        var stored = try keystore.fetchKey(for: tag)
        defer { stored.resetBytes(in: stored.startIndex ..< stored.endIndex) }
        guard LegacySoraIdentityValidator.constantTimeEqual(stored, value) else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        return .added
    }
}

/// Startup backfill for downgrade safety: every signing account ends up with
/// a scoped `<address>-secretKey` (and, for phrase accounts, `-seed`), which
/// is what App Store 3.8.6 needs if it ever runs over this data again.
///
/// - Accounts backed only by the unsuffixed 1.x `seedEntropy` (sr25519,
///   default path) get `-entropy`, `-seed` and `-secretKey`, in that order,
///   so an interrupted run leaves the phrase first. 3.8.6 deletes
///   `seedEntropy` on every launch with a selected account.
/// - Accounts with a scoped phrase or seed but no `-secretKey` (restored by
///   phrase or seed, any crypto type or path, or an interrupted write) get the
///   missing `-seed` and `-secretKey` (`WalletScopedKeyCompletion`).
///
/// Add-only, proven before writing, read back; the global items
/// (`seedEntropy`, `privateKey`, `userName`) are never touched; an existing
/// item that differs stops that account without writing.
enum LegacyGlobalEntropyScopedBackfill {
    struct Result: Equatable {
        var completed: [String] = []
        var conflicts: [String] = []
    }

    @discardableResult
    static func run(
        accounts: [AccountItem],
        snapshot: WalletNetworkSnapshot,
        keystore: KeystoreProtocol,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws -> Result {
        try recoveryGate.requireMutableWalletAccess()
        var result = Result()
        for account in accounts {
            guard
                let wallet = snapshot.wallets.first(where: { $0.id == account.address }),
                wallet.secretSource != .watchOnly,
                wallet.secretSource != .signingUnavailable
            else { continue }

            let entropyTag = KeystoreTag.entropyTagForAddress(account.address)
            let seedTag = KeystoreTag.seedTagForAddress(account.address)
            let secretTag = KeystoreTag.secretKeyTagForAddress(account.address)
            let hasEntropy = try keystore.checkKey(for: entropyTag)
            let hasSeed = try keystore.checkKey(for: seedTag)
            let hasSecret = try keystore.checkKey(for: secretTag)
            guard !hasSecret else { continue }

            if hasEntropy || hasSeed {
                switch try WalletScopedKeyCompletion.addMissingCopies(
                    for: account, keystore: keystore, recoveryGate: recoveryGate
                ) {
                case .added: result.completed.append(account.address)
                case .conflict: result.conflicts.append(account.address)
                case .complete, .nothingToDeriveFrom: break
                }
                continue
            }

            // Only the unsuffixed 1.x entropy can back this account.
            guard
                account.cryptoType == .sr25519,
                account.networkType == SNAddressType(chain: .sora),
                wallet.secretSource == .mnemonicEntropy || wallet.secretSource == .legacyMnemonicEntropy,
                try !keystore.checkKey(for: KeystoreTag.deriviationTagForAddress(account.address))
            else { continue }

            var resolved: Data?
            do {
                resolved = try keystore.fetchEntropyForAddress(
                    account.address,
                    activeSnapshot: snapshot,
                    recoveryGate: recoveryGate
                )
            } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
                resolved = nil
            }
            guard var entropy = resolved, WalletMnemonicWordPolicy.isDerivableEntropy(entropy) else {
                continue
            }
            defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
            guard var derived = try WalletScopedKeyDerivation.derive(
                cryptoType: .sr25519, derivationPath: nil, entropy: entropy, rawSeed: nil
            ) else { continue }
            defer { derived.wipe() }

            do {
                try LegacySoraIdentityValidator.validate(
                    address: account.address,
                    publicKey: account.publicKeyData,
                    cryptoType: .sr25519,
                    networkType: account.networkType,
                    derivationPath: nil,
                    entropy: entropy,
                    rawSeed: derived.seed,
                    secret: derived.secret,
                    recoveryGate: recoveryGate
                )
            } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
                result.conflicts.append(account.address)
                continue
            }

            var stopped = false
            for (tag, value, isSecret) in [
                (entropyTag, entropy, false), (seedTag, derived.seed, false), (secretTag, derived.secret, true),
            ] {
                try recoveryGate.requireAuthorizedLifecycleContinuation()
                if try WalletScopedKeyWrite.addIfAbsent(
                    value, tag: tag, isSecret: isSecret, cryptoType: .sr25519, keystore: keystore
                ) == .differs {
                    stopped = true
                    break
                }
            }
            if stopped {
                result.conflicts.append(account.address)
            } else {
                result.completed.append(account.address)
            }
        }
        if !result.completed.isEmpty {
            Logger.shared.info("Wallet keys: scoped copies added for \(result.completed.count) account(s)")
        }
        if !result.conflicts.isEmpty {
            Logger.shared.warning("Wallet keys: scoped copies skipped for \(result.conflicts.count) account(s)")
        }
        return result
    }
}

// MARK: - Retained PIN

/// Checks a PIN against the PIN of an earlier install, before restoring the
/// wallets that install left in the Keychain or showing their phrases.
///
/// - Welcome back (no wallet on this install yet): the `pincode` item is
///   still the earlier install's PIN.
/// - After setup: onboarding has replaced `pincode` with this install's PIN.
///   Before it does, `preserveEarlierInstallPin` keeps a copy of the earlier
///   PIN (add-only), and only those copies unlock retained wallets. This
///   install's PIN alone never does: it was chosen by whoever set up this
///   install, not by the owner of the retained wallets.
///
/// Wrong PINs lead to waits of 1, 5, 15 and then 30 minutes after the third
/// failure, as on the normal PIN screen. There is no permanent lock; the
/// recovery phrase and Google Drive backup stay available throughout.
enum WalletRetainedPinGate {
    static let failuresBeforeWait = 3
    static let failureCountKey = "wallet.retainedPinFailures"
    static let lockedUntilKey = "wallet.retainedPinLockedUntil"
    static let earlierInstallPinTagPrefix = "earlierInstallPin-"
    static let maximumEarlierInstallPins = 4

    enum Scope: Equatable {
        case welcomeBack
        case afterSetup
    }

    enum Failure: Error, Equatable {
        case noRetainedPin
        case incorrectPin(attemptsBeforeWait: Int)
        case locked(until: Date)
    }

    static func cooldown(afterFailures count: Int) -> TimeInterval {
        switch count {
        case ..<failuresBeforeWait: return 0
        case failuresBeforeWait: return 60
        case failuresBeforeWait + 1: return 5 * 60
        case failuresBeforeWait + 2: return 15 * 60
        default: return 30 * 60
        }
    }

    static func earlierInstallPinTags(keystore: KeystoreProtocol) throws -> [String] {
        try keystore.allKeyIdentifiers().filter { $0.hasPrefix(earlierInstallPinTagPrefix) }.sorted()
    }

    private static func candidateTags(scope: Scope, keystore: KeystoreProtocol) throws -> [String] {
        var tags = try earlierInstallPinTags(keystore: keystore)
        if scope == .welcomeBack, try keystore.checkKey(for: KeystoreTag.pincode.rawValue) {
            tags.insert(KeystoreTag.pincode.rawValue, at: 0)
        }
        return tags
    }

    static func hasRetainedPin(keystore: KeystoreProtocol, scope: Scope = .welcomeBack) -> Bool {
        (try? candidateTags(scope: scope, keystore: keystore).isEmpty == false) == true
    }

    /// When a wait is running, its end.
    static func lockedUntil(settings: SettingsManagerProtocol, now: Date = Date()) -> Date? {
        guard let value = settings.integer(for: lockedUntilKey) else { return nil }
        let until = Date(timeIntervalSince1970: TimeInterval(value))
        return until > now ? until : nil
    }

    /// A PIN path exists (a wait, if running, ends by itself).
    static func isUsable(
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        scope: Scope = .welcomeBack
    ) -> Bool {
        hasRetainedPin(keystore: keystore, scope: scope)
    }

    static func verify(
        _ pin: String,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        scope: Scope = .welcomeBack,
        now: Date = Date()
    ) throws {
        if let until = lockedUntil(settings: settings, now: now) {
            throw Failure.locked(until: until)
        }
        let tags = try candidateTags(scope: scope, keystore: keystore)
        guard !tags.isEmpty else { throw Failure.noRetainedPin }
        var entered = Data(pin.utf8)
        defer { entered.resetBytes(in: entered.startIndex ..< entered.endIndex) }
        var matched = false
        if !entered.isEmpty {
            for tag in tags {
                var stored = try keystore.fetchKey(for: tag)
                defer { stored.resetBytes(in: stored.startIndex ..< stored.endIndex) }
                if LegacySoraIdentityValidator.constantTimeEqual(stored, entered) {
                    matched = true
                }
            }
        }
        guard matched else {
            let failures = (settings.integer(for: failureCountKey) ?? 0) + 1
            settings.set(value: failures, for: failureCountKey)
            let wait = cooldown(afterFailures: failures)
            guard wait > 0 else {
                throw Failure.incorrectPin(attemptsBeforeWait: failuresBeforeWait - failures)
            }
            let until = now.addingTimeInterval(wait)
            settings.set(value: Int(until.timeIntervalSince1970.rounded(.up)), for: lockedUntilKey)
            throw Failure.locked(until: until)
        }
        settings.removeValue(for: failureCountKey)
        settings.removeValue(for: lockedUntilKey)
    }

    /// Keeps a copy of the current `pincode` (the earlier install's PIN while
    /// no wallet exists) before onboarding replaces it, so wallets that stay
    /// in the Keychain can still be restored with that PIN later. Add-only
    /// and read back; an identical copy is not added twice. Returns true when
    /// a copy was added.
    @discardableResult
    static func preserveEarlierInstallPin(keystore: KeystoreProtocol) throws -> Bool {
        guard try keystore.checkKey(for: KeystoreTag.pincode.rawValue) else { return false }
        var current = try keystore.fetchKey(for: KeystoreTag.pincode.rawValue)
        defer { current.resetBytes(in: current.startIndex ..< current.endIndex) }
        guard !current.isEmpty else { return false }
        let existing = try earlierInstallPinTags(keystore: keystore)
        for tag in existing {
            var stored = try keystore.fetchKey(for: tag)
            defer { stored.resetBytes(in: stored.startIndex ..< stored.endIndex) }
            if LegacySoraIdentityValidator.constantTimeEqual(stored, current) { return false }
        }
        guard existing.count < maximumEarlierInstallPins else { return false }
        var index = 1
        while existing.contains("\(earlierInstallPinTagPrefix)\(index)") { index += 1 }
        let tag = "\(earlierInstallPinTagPrefix)\(index)"
        try keystore.addKey(current, with: tag)
        var stored = try keystore.fetchKey(for: tag)
        defer { stored.resetBytes(in: stored.startIndex ..< stored.endIndex) }
        guard LegacySoraIdentityValidator.constantTimeEqual(stored, current) else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        return true
    }
}

// MARK: - Wallets found in the Keychain (reinstall)

/// A wallet whose retained Keychain items prove its tagged address.
struct RetainedKeychainWallet: Equatable {
    let address: String
    let publicKey: Data
    let cryptoType: CryptoType
    let networkType: SNAddressType
    let derivationPath: String?
    let hasPhrase: Bool
    /// Backed only by the unsuffixed 1.x `seedEntropy` (sr25519, default
    /// path), proven like the explicit 1.x upgrade, including the retained
    /// Iroha `privateKey` when present. Restoring it adds scoped copies.
    var usesGlobalEntropy = false
}

/// Finds wallets an earlier install left in the Keychain (iOS keeps Keychain
/// items when an app is deleted). Read-only: nothing is written here.
///
/// A wallet is adoptable only when its own `<address>-entropy`, `-seed` or
/// `-secretKey` proves the SORA address it is tagged with (same checks as an
/// upgrade, including the signature challenge), or when the unsuffixed 1.x
/// `seedEntropy` proves its default-path address. Anything that does not
/// prove its address is ignored and left untouched.
enum RetainedKeychainWalletDiscovery {
    struct Inventory: Equatable {
        var adoptable: [RetainedKeychainWallet] = []
        var unprovableAddressCount = 0
    }

    /// The outcome of restoring several wallets. Each wallet is restored on
    /// its own; one failure does not undo or stop the others.
    struct RestoreResult {
        var restored: [AccountItem] = []
        var failedAddresses: [String] = []
        var firstError: Error?
    }

    private static let scopedSuffixes = ["-secretKey", "-entropy", "-seed"]

    static func inventory(
        keystore: KeystoreProtocol,
        excluding existingAddresses: Set<String> = [],
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws -> Inventory {
        let identifiers = try keystore.allKeyIdentifiers()
        var addresses = Set<String>()
        for identifier in identifiers {
            for suffix in scopedSuffixes where identifier.hasSuffix(suffix) && identifier.count > suffix.count {
                addresses.insert(String(identifier.dropLast(suffix.count)))
            }
        }
        var inventory = Inventory()
        for address in addresses.subtracting(existingAddresses).sorted() {
            if let wallet = try prove(address: address, keystore: keystore, recoveryGate: recoveryGate) {
                inventory.adoptable.append(wallet)
            } else {
                inventory.unprovableAddressCount += 1
            }
        }
        // A wallet backed only by the 1.x `seedEntropy`. When scoped items
        // exist for its address, those decide (above).
        switch try proveGlobalEntropy(keystore: keystore, recoveryGate: recoveryGate) {
        case let .proven(wallet) where !addresses.contains(wallet.address) &&
            !existingAddresses.contains(wallet.address):
            inventory.adoptable.append(wallet)
        case .unprovable:
            inventory.unprovableAddressCount += 1
        case .proven, .absent:
            break
        }
        return inventory
    }

    enum GlobalEntropyProof: Equatable {
        case absent
        case unprovable
        case proven(RetainedKeychainWallet)
    }

    /// Proves the unsuffixed `seedEntropy` the way the explicit 1.x upgrade
    /// does: a 12–24 word phrase, the retained Iroha `privateKey` (if any)
    /// derived from it, and the sr25519 default-path SORA address with a
    /// signature. Keychain read errors propagate (retry).
    static func proveGlobalEntropy(
        keystore: KeystoreProtocol,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws -> GlobalEntropyProof {
        guard try keystore.checkKey(for: KeystoreTag.legacyEntropy.rawValue) else { return .absent }
        var entropy = try keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue)
        defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
        guard WalletMnemonicWordPolicy.isDerivableEntropy(entropy) else { return .unprovable }
        do {
            let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy)
            guard WalletMnemonicWordPolicy.retainedSoraWordCounts.contains(mnemonic.allWords().count) else {
                return .unprovable
            }
            try keystore.verifyLegacyIrohaKeyIfPresent(entropy: entropy)
            guard var derived = try WalletScopedKeyDerivation.derive(
                cryptoType: .sr25519, derivationPath: nil, entropy: entropy, rawSeed: nil
            ) else { return .unprovable }
            defer { derived.wipe() }
            let soraType = SNAddressType(chain: .sora)
            let publicKey = try SR25519KeypairFactory()
                .createKeypairFromSeed(derived.seed, chaincodeList: []).publicKey().rawData()
            let address = try SS58AddressFactory().address(fromAccountId: publicKey, type: soraType)
            try LegacySoraIdentityValidator.validate(
                address: address, publicKey: publicKey, cryptoType: .sr25519, networkType: soraType,
                derivationPath: nil, entropy: entropy, rawSeed: nil, secret: nil, recoveryGate: recoveryGate
            )
            return .proven(RetainedKeychainWallet(
                address: address, publicKey: publicKey, cryptoType: .sr25519, networkType: soraType,
                derivationPath: nil, hasPhrase: true, usesGlobalEntropy: true
            ))
        } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
            return .unprovable
        }
    }

    /// Proves one tagged address. Keychain read errors propagate (retry);
    /// material that does not prove the address returns nil.
    static func prove(
        address: String,
        keystore: KeystoreProtocol,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws -> RetainedKeychainWallet? {
        let soraType = SNAddressType(chain: .sora)
        guard let type = try? SS58AddressFactory().type(fromAddress: address).uint16Value,
              type == soraType else {
            return nil
        }
        var entropy = try keystore.loadIfKeyExists(KeystoreTag.entropyTagForAddress(address))
        var seed = try keystore.loadIfKeyExists(KeystoreTag.seedTagForAddress(address))
        var secret = try keystore.loadIfKeyExists(KeystoreTag.secretKeyTagForAddress(address))
        defer {
            if let count = entropy?.count { entropy?.resetBytes(in: 0 ..< count) }
            if let count = seed?.count { seed?.resetBytes(in: 0 ..< count) }
            if let count = secret?.count { secret?.resetBytes(in: 0 ..< count) }
        }
        let derivationPath = try keystore.fetchDeriviationForAddress(address)
        guard entropy != nil || seed != nil || secret != nil else { return nil }

        for cryptoType in [CryptoType.sr25519, .ed25519, .ecdsa] {
            do {
                guard let publicKey = try candidatePublicKey(
                    address: address, cryptoType: cryptoType, entropy: entropy,
                    seed: seed, secret: secret, derivationPath: derivationPath
                ), try SS58AddressFactory().address(fromAccountId: publicKey, type: type) == address
                else { continue }
                try LegacySoraIdentityValidator.validate(
                    address: address,
                    publicKey: publicKey,
                    cryptoType: cryptoType,
                    networkType: type,
                    derivationPath: derivationPath,
                    entropy: entropy,
                    rawSeed: seed,
                    secret: secret,
                    recoveryGate: recoveryGate
                )
                return RetainedKeychainWallet(
                    address: address,
                    publicKey: publicKey,
                    cryptoType: cryptoType,
                    networkType: type,
                    derivationPath: derivationPath,
                    hasPhrase: entropy.map(WalletMnemonicWordPolicy.isDerivableEntropy) == true
                )
            } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
                continue
            }
        }
        return nil
    }

    private static func candidatePublicKey(
        address: String,
        cryptoType: CryptoType,
        entropy: Data?,
        seed: Data?,
        secret: Data?,
        derivationPath: String?
    ) throws -> Data? {
        let path = derivationPath ?? ""
        let junction = path.isEmpty ? nil : try SubstrateJunctionFactory().parse(path: path)
        let chaincodes = junction?.chaincodes ?? []
        var sourceSeed: Data?
        defer {
            if let count = sourceSeed?.count { sourceSeed?.resetBytes(in: 0 ..< count) }
        }
        if let entropy, WalletMnemonicWordPolicy.isDerivableEntropy(entropy) {
            var phrase = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy).toString()
            defer { phrase.removeAll(keepingCapacity: false) }
            sourceSeed = try SeedFactory().deriveSeed(from: phrase, password: junction?.password ?? "").seed.miniSeed
        } else if let seed {
            sourceSeed = seed
        }
        if let sourceSeed {
            let factory: KeypairFactoryProtocol
            switch cryptoType {
            case .sr25519: factory = SR25519KeypairFactory()
            case .ed25519: factory = Ed25519KeypairFactory()
            case .ecdsa: factory = EcdsaKeypairFactory()
            }
            return try factory.createKeypairFromSeed(sourceSeed, chaincodeList: chaincodes).publicKey().rawData()
        }
        guard let secret else { return nil }
        switch cryptoType {
        case .sr25519:
            // The SS58 account id of an sr25519 account is its public key.
            // The validator proves the secret with a signature over it.
            return try SS58AddressFactory().accountId(fromAddress: address, type: SNAddressType(chain: .sora))
        case .ed25519:
            return try Ed25519KeypairFactory().createKeypairFromSeed(secret.miniSeed, chaincodeList: [])
                .publicKey().rawData()
        case .ecdsa:
            return try EcdsaKeypairFactory().createKeypairFromSeed(secret.miniSeed, chaincodeList: [])
                .publicKey().rawData()
        }
    }

    /// Builds the in-memory account for a proven wallet. Persisting it adopts
    /// the retained items (they already match) and adds only absent scoped
    /// copies; it never rewrites an existing item.
    static func preparedAccount(
        for wallet: RetainedKeychainWallet,
        username: String,
        keystore: KeystoreProtocol,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws -> PreparedAccount {
        let factory = AccountOperationFactory(keystore: keystore, recoveryGate: recoveryGate)
        let operation: BaseOperation<PreparedAccount>
        if wallet.usesGlobalEntropy {
            guard try proveGlobalEntropy(keystore: keystore, recoveryGate: recoveryGate) == .proven(wallet) else {
                throw AccountCreateError.retainedKeyConflict
            }
            var entropy = try keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue)
            defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
            operation = factory.prepareAccountOperation(
                request: AccountCreationRequest(username: username, type: .sora, derivationPath: "",
                                                cryptoType: .sr25519),
                mnemonic: try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy)
            )
            return try finish(operation, for: wallet)
        }
        guard let proven = try prove(address: wallet.address, keystore: keystore, recoveryGate: recoveryGate),
              proven == wallet else {
            throw AccountCreateError.retainedKeyConflict
        }
        var entropy = try keystore.loadIfKeyExists(KeystoreTag.entropyTagForAddress(wallet.address))
        defer { if let count = entropy?.count { entropy?.resetBytes(in: 0 ..< count) } }
        if let phraseEntropy = entropy, WalletMnemonicWordPolicy.isDerivableEntropy(phraseEntropy) {
            let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: phraseEntropy)
            operation = factory.prepareAccountOperation(
                request: AccountCreationRequest(
                    username: username,
                    type: .sora,
                    derivationPath: wallet.derivationPath ?? "",
                    cryptoType: wallet.cryptoType
                ),
                mnemonic: mnemonic
            )
        } else if var seed = try keystore.loadIfKeyExists(KeystoreTag.seedTagForAddress(wallet.address)) {
            defer { seed.resetBytes(in: seed.startIndex ..< seed.endIndex) }
            operation = factory.prepareAccountOperation(
                request: AccountImportSeedRequest(
                    seed: seed.toHex(),
                    username: username,
                    networkType: .sora,
                    derivationPath: wallet.derivationPath ?? "",
                    cryptoType: wallet.cryptoType
                )
            )
        } else {
            var secret = try keystore.fetchKey(for: KeystoreTag.secretKeyTagForAddress(wallet.address))
            defer { secret.resetBytes(in: secret.startIndex ..< secret.endIndex) }
            return try PreparedAccount(
                account: AccountItem(
                    address: wallet.address,
                    cryptoType: wallet.cryptoType,
                    networkType: wallet.networkType,
                    username: username,
                    publicKeyData: wallet.publicKey,
                    settings: AccountSettings(visibleAssetIds: [], orderedAssetIds: []),
                    order: 0,
                    isSelected: true
                ),
                secretKey: secret,
                entropy: nil,
                seed: nil,
                derivationPath: wallet.derivationPath,
                recoveryGate: recoveryGate
            )
        }
        return try finish(operation, for: wallet)
    }

    private static func finish(
        _ operation: BaseOperation<PreparedAccount>,
        for wallet: RetainedKeychainWallet
    ) throws -> PreparedAccount {
        operation.start()
        let prepared = try operation.extractNoCancellableResultData()
        guard prepared.account.address == wallet.address,
              prepared.account.publicKeyData == wallet.publicKey else {
            prepared.discard()
            throw AccountCreateError.retainedKeyConflict
        }
        return prepared
    }
}

// MARK: - Show the recovery phrase after the PIN

/// Reads the recovery phrase of accounts whose phrase entropy is on this
/// device and proves the account address, after a retained PIN is verified.
/// The phrase comes from the account's scoped `-entropy`, or, for a 1.x
/// account (sr25519, default path) without one, from `seedEntropy`.
/// Read-only.
enum WalletRecoveryPhraseReveal {
    struct Entry: Equatable {
        let address: String
        let name: String
        let words: [String]
    }

    /// Accounts whose phrase can be shown (no PIN check, no secret returned).
    static func availableAddresses(
        accounts: [AccountItem],
        keystore: KeystoreProtocol,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) -> [String] {
        accounts.compactMap { account in
            (try? phraseWords(for: account, keystore: keystore, recoveryGate: recoveryGate)) != nil
                ? account.address : nil
        }
    }

    static func reveal(
        pin: String,
        accounts: [AccountItem],
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        scope: WalletRetainedPinGate.Scope = .welcomeBack,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws -> [Entry] {
        try WalletRetainedPinGate.verify(pin, keystore: keystore, settings: settings, scope: scope)
        return try accounts.compactMap { account in
            guard let words = try phraseWords(for: account, keystore: keystore, recoveryGate: recoveryGate) else {
                return nil
            }
            return Entry(address: account.address, name: account.username, words: words)
        }
    }

    private static func phraseWords(
        for account: AccountItem,
        keystore: KeystoreProtocol,
        recoveryGate: WalletRecoveryCapabilityGate
    ) throws -> [String]? {
        let derivationPath = try keystore.fetchDeriviationForAddress(account.address)
        var entropy: Data
        if let scoped = try keystore.loadIfKeyExists(KeystoreTag.entropyTagForAddress(account.address)) {
            entropy = scoped
        } else if account.cryptoType == .sr25519, (derivationPath ?? "").isEmpty,
                  let global = try keystore.loadIfKeyExists(KeystoreTag.legacyEntropy.rawValue) {
            entropy = global
        } else {
            return nil
        }
        defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
        guard WalletMnemonicWordPolicy.isDerivableEntropy(entropy) else { return nil }
        do {
            try LegacySoraIdentityValidator.validate(
                address: account.address,
                publicKey: account.publicKeyData,
                cryptoType: account.cryptoType,
                networkType: account.networkType,
                derivationPath: derivationPath,
                entropy: entropy,
                rawSeed: nil,
                secret: nil,
                recoveryGate: recoveryGate
            )
        } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
            return nil
        }
        return try IRMnemonicCreator(language: .english).mnemonic(fromEntropy: entropy).allWords()
    }
}

// MARK: - Restore wallets found in the Keychain

extension RetainedKeychainWalletDiscovery {
    /// Adds account rows for proven retained wallets, through the normal
    /// journaled insert. Each wallet's retained items are adopted (they
    /// match); only absent scoped copies are added. Wallets are restored one
    /// by one: a failure is recorded and the others still run, and wallets
    /// already restored stay. The first wallet restored last ends up
    /// selected. Pass the addresses already in the wallet as `existing`: they
    /// are skipped. Call from a background queue.
    @discardableResult
    static func restore(
        _ wallets: [RetainedKeychainWallet],
        existing existingAddresses: Set<String> = [],
        keystore: KeystoreProtocol,
        selectedWalletSettings: SelectedWalletSettingsProtocol,
        lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
        recoveryGate: WalletRecoveryCapabilityGate = .shared,
        username: (Int) -> String = { index in
            index == 0
                ? WalletUX.text("Restored wallet")
                : "\(WalletUX.text("Restored wallet")) \(index + 1)"
        }
    ) -> RestoreResult {
        var result = RestoreResult()
        for (index, wallet) in wallets.enumerated().reversed() where !existingAddresses.contains(wallet.address) {
            do {
                let prepared = try preparedAccount(
                    for: wallet, username: username(index), keystore: keystore, recoveryGate: recoveryGate)
                let lease = lifecycleCoordinator.acquire()
                let finished = DispatchSemaphore(value: 0)
                var outcome: Result<AccountItem, Error> = .failure(AccountCreateError.retainedKeyConflict)
                selectedWalletSettings.performInsertAndSelect(
                    prepared: prepared,
                    persistSecrets: {
                        try recoveryGate.requireAuthorizedLifecycleContinuation()
                        try prepared.persist(to: keystore)
                    },
                    lifecycleLease: lease
                ) { insertResult in
                    outcome = insertResult
                    finished.signal()
                }
                finished.wait()
                lease.release()
                result.restored.append(try outcome.get())
            } catch {
                result.failedAddresses.append(wallet.address)
                if result.firstError == nil { result.firstError = error }
                Logger.shared.warning(
                    "Wallet keys: a retained wallet was not restored (\(UserStorageMigrationError.privacySafeOutcomeCode(for: error)))"
                )
            }
        }
        return result
    }
}

// MARK: - Per-account key availability

/// Whether an account can sign on this device, decided from its keys (not
/// only from the recorded source). Read-only; used to show an account as
/// read-only and to choose the restore action.
enum WalletAccountKeyAvailability: Equatable {
    /// Its keys on this device prove the account.
    case available
    /// An explicit watch-only account.
    case watchOnly
    /// No key for it is on this device (for example a new iPhone).
    /// Importing its phrase or Google Drive backup restores it in place.
    case keysMissing
    /// Keys are present but do not prove it. They are left untouched.
    case keysNotVerified

    var isReadOnlyOnThisDevice: Bool { self != .available }

    static func status(
        for account: AccountItem,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        activeSnapshot: WalletNetworkSnapshot?,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws -> WalletAccountKeyAvailability {
        if settings.bool(for: "wallet.watchOnly.\(account.address)") == true { return .watchOnly }
        var entropy: Data?
        do {
            if let activeSnapshot {
                entropy = try keystore.fetchEntropyForAddress(
                    account.address, activeSnapshot: activeSnapshot, recoveryGate: recoveryGate)
            } else {
                entropy = try keystore.loadIfKeyExists(KeystoreTag.entropyTagForAddress(account.address))
            }
        } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
            entropy = nil
        }
        var seed = try keystore.fetchSeedForAddress(account.address)
        var secret = try keystore.fetchSecretKeyForAddress(account.address)
        defer {
            if let count = entropy?.count { entropy?.resetBytes(in: 0 ..< count) }
            if let count = seed?.count { seed?.resetBytes(in: 0 ..< count) }
            if let count = secret?.count { secret?.resetBytes(in: 0 ..< count) }
        }
        guard entropy != nil || seed != nil || secret != nil else { return .keysMissing }
        do {
            try LegacySoraIdentityValidator.validate(
                address: account.address,
                publicKey: account.publicKeyData,
                cryptoType: account.cryptoType,
                networkType: account.networkType,
                derivationPath: try keystore.fetchDeriviationForAddress(account.address),
                entropy: entropy,
                rawSeed: seed,
                secret: secret,
                recoveryGate: recoveryGate
            )
            return .available
        } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
            return .keysNotVerified
        }
    }
}

// MARK: - Account addresses in the wallet database

enum WalletAccountAddresses {
    /// The addresses of every account row. Call from a background queue.
    static func current(storageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared) throws -> Set<String> {
        let repository: CoreDataRepository<AccountItem, CDAccountItem> = storageFacade.createRepository(
            filter: nil, sortDescriptors: [], mapper: AnyCoreDataMapper(AccountItemMapper()))
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        let queue = OperationQueue()
        queue.addOperations([operation], waitUntilFinished: true)
        return Set(try operation.extractNoCancellableResultData().map(\.address))
    }
}
