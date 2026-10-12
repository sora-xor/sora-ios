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

import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto
import SSFCloudStorage

final class AccountOptionsInteractor {
    weak var presenter: AccountOptionsInteractorOutputProtocol!

    private(set) var keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol
    private(set) var cacheFacade: CacheFacadeProtocol
    private(set) var userDataFacade: StorageFacadeProtocol
    private(set) var substrateDataFacade: StorageFacadeProtocol
    private let account: AccountItem
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol
    private var chain: ChainModel
    private let mnemonicCreator: IRMnemonicCreatorProtocol
    private var cloudStorageService: CloudStorageServiceProtocol

    init(keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         chain: ChainModel,
         cacheFacade: CacheFacadeProtocol,
         substrateDataFacade: StorageFacadeProtocol,
         userDataFacade: StorageFacadeProtocol,
         account: AccountItem,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         eventCenter: EventCenterProtocol,
         mnemonicCreator: IRMnemonicCreatorProtocol,
         cloudStorageService: CloudStorageServiceProtocol) {
        self.keystore = keystore
        self.settings = settings
        self.cacheFacade = cacheFacade
        self.substrateDataFacade = substrateDataFacade
        self.userDataFacade = userDataFacade
        self.account = account
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.chain = chain
        self.mnemonicCreator = mnemonicCreator
        self.cloudStorageService = cloudStorageService
        self.eventCenter.add(observer: self)
    }
    
    private func loadPhrase() throws -> IRMnemonicProtocol? {
        var backup = try WalletBackupMaterial.load(for: account, keystore: keystore)
        defer { backup.wipe() }
        guard let entropy = backup.entropy else { return nil }
        let mnemonic = try mnemonicCreator.mnemonic(fromEntropy: entropy)
        return mnemonic
    }
}

extension AccountOptionsInteractor: AccountOptionsInteractorInputProtocol {

    var currentAccount: AccountItem {
        account
    }

    var accountHasEntropy: Bool {
        (try? loadPhrase()) != nil

    }

    func getMetadata() -> AccountCreationMetadata? {
        guard let mnemonic = try? loadPhrase() else { return nil }
        
        let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                               availableNetworks: Chain.allCases,
                                               defaultNetwork: .sora,
                                               availableCryptoTypes: CryptoType.allCases,
                                               defaultCryptoType: account.cryptoType)
        return metadata
    }

    func updateUsername(_ username: String) {
        SelectedWalletSettings.shared.performUpdateName(
            account: account,
            displayName: username
        ) { [weak self] result in
            guard case .success = result else {
                return
            }
            DispatchQueue.main.async {
                self?.eventCenter.notify(with: SelectedUsernameChanged())
            }
        }
    }

    func isLastAccountWithCustomNodes(completion: @escaping (Bool) -> Void) {
        getAccounts { [weak self] accounts in
            guard let self = self else { return }

            let customNodes = self.chain.customNodes ?? []
            completion(accounts.count == 1 && !(customNodes.isEmpty))
        }
    }
    
    func deleteBackup(completion: @escaping (Error?) -> Void) {
        let account = OpenBackupAccount(address: currentAccount.address)
        Task { [weak self] in
            do {
                try WalletRecoveryCapabilityGate.shared
                    .requireAuthorizedLifecycleContinuation()
                try await self?.cloudStorageService.deleteBackup(account: account)
                try WalletRecoveryCapabilityGate.shared
                    .requireAuthorizedLifecycleContinuation()
                let backupedAddresses = ApplicationConfig.shared.backupedAccountAddresses
                ApplicationConfig.shared.backupedAccountAddresses = backupedAddresses.filter { $0 != self?.currentAccount.address }
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func signInToGoogleIfNeeded(completion: ((OpenBackupAccount?) -> Void)?) {
        Task { [weak self] in
            guard let result = try await self?.cloudStorageService.signInIfNeeded(), result == .authorized, let self = self else {
                completion?(nil)
                return
            }

            let metadata = self.getMetadata()
            let account = OpenBackupAccount(name: self.currentAccount.username,
                                            address: self.currentAccount.address,
                                            passphrase: metadata?.mnemonic.joined(separator: " ") ?? "",
                                            cryptoType: currentAccount.cryptoType.typeString,
                                            substrateDerivationPath: "")
            completion?(account)
        }
    }
    
    func checkCurrentAccountBackedup() async -> Bool {
        do {
            let accounts = try await cloudStorageService.getBackupAccounts()
            let backupedAddresses = accounts.map { $0.address }
            
            let searchingResult = backupedAddresses.contains(currentAccount.address)
            return searchingResult
        } catch {
            return false
        }
    }

    func logoutAndClean() {
        let lifecycleCoordinator = WalletLifecycleCoordinator.shared
        let lifecycleOperation =
            lifecycleCoordinator.makeAcquireOperation()
        let idToRemove = self.account.identifier
        let pendingTransactionPreflight =
            WalletPendingDeletionPreflightOperation(
                lifecycleOperation: lifecycleOperation,
                walletId: idToRemove,
                soraAddress: account.address
            )
        pendingTransactionPreflight.addDependency(lifecycleOperation)
        let inventoryOperation = accountRepository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )
        inventoryOperation.addDependency(lifecycleOperation)
        let identityPreflightOperation: BaseOperation<WalletExplicitRemovalPlan> =
            ClosureOperation {
                _ = try lifecycleOperation
                    .extractNoCancellableResultData()
                _ = try pendingTransactionPreflight
                    .extractNoCancellableResultData()
                try WalletRecoveryCapabilityGate.shared
                    .requireAuthorizedLifecycleContinuation()
                let accounts = try inventoryOperation
                    .extractNoCancellableResultData()
                return try self.verifyExplicitRemovalIdentity(
                    accounts: accounts,
                    walletId: idToRemove
                )
            }
        identityPreflightOperation.addDependency(inventoryOperation)
        identityPreflightOperation.addDependency(
            pendingTransactionPreflight
        )
        let recordRemovalOperation: BaseOperation<WalletNetworkSnapshot> =
            ClosureOperation {
                _ = try lifecycleOperation
                    .extractNoCancellableResultData()
                _ = try pendingTransactionPreflight
                    .extractNoCancellableResultData()
                _ = try identityPreflightOperation
                    .extractNoCancellableResultData()
                try WalletRecoveryCapabilityGate.shared
                    .requireAuthorizedLifecycleContinuation()
                let accounts = try inventoryOperation
                    .extractNoCancellableResultData()
                let walletIds = accounts.map(\.identifier)
                guard
                    Set(walletIds).count == walletIds.count,
                    walletIds.filter({ $0 == idToRemove }).count == 1
                else {
                    throw WalletNetworkMigrationError
                        .explicitRemovalInventoryMismatch
                }
                let legacySelectedAddress = self.settings.value(
                    of: AccountItem.self,
                    for: SettingsKey.selectedAccount.rawValue
                )?.identifier
                let selectedAccount = try SelectedWalletSettings
                    .resolveSelection(
                        accounts: accounts,
                        legacySelectedAddress: legacySelectedAddress
                    )
                guard let selectedAccount else {
                    throw WalletNetworkMigrationError
                        .explicitRemovalSelectionMismatch
                }
                return try WalletNetworkStore().recordExplicitRemoval(
                    walletId: idToRemove,
                    expectedWalletIds: walletIds,
                    selectedWalletId: selectedAccount.identifier
                )
            }
        recordRemovalOperation.addDependency(inventoryOperation)
        recordRemovalOperation.addDependency(pendingTransactionPreflight)
        recordRemovalOperation.addDependency(identityPreflightOperation)

        let forgetOperation = accountRepository.saveOperation {
            try WalletRecoveryCapabilityGate.shared
                .requireAuthorizedLifecycleContinuation()
            let accounts = try inventoryOperation
                .extractNoCancellableResultData()
            let networkSnapshot = try recordRemovalOperation
                .extractNoCancellableResultData()
            guard try WalletNetworkStore().load() == networkSnapshot else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            let remainingAccounts = accounts.filter {
                $0.identifier != idToRemove
            }
            guard
                Set(remainingAccounts.map(\.identifier)) ==
                    Set(networkSnapshot.wallets.map(\.id))
            else {
                throw WalletNetworkMigrationError
                    .explicitRemovalInventoryMismatch
            }
            return remainingAccounts.compactMap { account in
                let shouldBeSelected =
                    account.identifier ==
                    networkSnapshot.selectedWalletId
                guard account.isSelected != shouldBeSelected else {
                    return nil
                }
                return AccountItem(
                    address: account.address,
                    cryptoType: account.cryptoType,
                    networkType: account.networkType,
                    username: account.username,
                    publicKeyData: account.publicKeyData,
                    settings: account.settings,
                    order: account.order,
                    isSelected: shouldBeSelected
                )
            }
        } _: {
            try WalletRecoveryCapabilityGate.shared
                .requireAuthorizedLifecycleContinuation()
            let networkSnapshot = try recordRemovalOperation
                .extractNoCancellableResultData()
            guard try WalletNetworkStore().load() == networkSnapshot else {
                throw WalletNetworkMigrationError
                    .snapshotVerificationFailed
            }
            return [idToRemove]
        }
        forgetOperation.addDependency(recordRemovalOperation)

        let countOperation = accountRepository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )
        countOperation.completionBlock = { [weak self] in
            let lifecycleLease: WalletLifecycleLease
            do {
                lifecycleLease = try lifecycleOperation
                    .extractNoCancellableResultData()
            } catch {
                self?.enterDeletionRecovery(error)
                return
            }
            guard let self else {
                lifecycleLease.release()
                return
            }
            do {
                try WalletRecoveryCapabilityGate.shared
                    .requireAuthorizedLifecycleContinuation()
                let networkSnapshot = try recordRemovalOperation
                    .extractNoCancellableResultData()
                let removalPlan =
                    try identityPreflightOperation
                        .extractNoCancellableResultData()
                _ = try forgetOperation.extractNoCancellableResultData()
                let accounts = try countOperation
                    .extractNoCancellableResultData()
                let selectedAccount = try self
                    .verifyAndCommitExplicitRemovalMetadata(
                        accounts: accounts,
                        networkSnapshot: networkSnapshot,
                        removedWalletId: idToRemove
                    )
                guard let selectedAccount else {
                    self.finishExplicitRemoval(
                        accounts: accounts,
                        lifecycleLease: lifecycleLease,
                        plan: removalPlan
                    )
                    return
                }
                SelectedWalletSettings.shared.performSelectAfterRemoval(
                    value: selectedAccount,
                    lifecycleLease: lifecycleLease
                ) { [weak self] result in
                    guard let self else {
                        lifecycleLease.release()
                        return
                    }
                    do {
                        _ = try result.get()
                        try self.verifyExplicitRemovalState(
                            accounts: accounts,
                            removedWalletId: idToRemove,
                            selectedWalletId:
                                selectedAccount.identifier
                        )
                        self.finishExplicitRemoval(
                            accounts: accounts,
                            lifecycleLease: lifecycleLease,
                            plan: removalPlan
                        )
                    } catch {
                        self.enterDeletionRecovery(
                            error,
                            lifecycleLease: lifecycleLease
                        )
                    }
                }
            } catch let error as WalletPendingDeletionPreflightError {
                lifecycleLease.release()
                DispatchQueue.main.async { [weak self] in
                    self?.presenter.accountDeletionBlocked(
                        message: error.localizedDescription
                    )
                }
            } catch {
                self.enterDeletionRecovery(
                    error,
                    lifecycleLease: lifecycleLease
                )
            }
        }

        countOperation.addDependency(forgetOperation)

        lifecycleCoordinator.enqueueOwnedAcquireOperation(
            lifecycleOperation
        )
        operationManager.enqueue(
            operations: [
                pendingTransactionPreflight,
                inventoryOperation,
                identityPreflightOperation,
                recordRemovalOperation,
                forgetOperation,
                countOperation
            ],
            in: .transient
        )
    }

}

enum WalletPendingDeletionPreflightError: LocalizedError, Equatable {
    case nexusJournalUnavailable
    case polkamarktJournalUnavailable
    case sora2JournalUnavailable
    case unresolvedNexusTransaction
    case unresolvedPolkamarktTransaction
    case unresolvedSora2Submission

    var errorDescription: String? {
        switch self {
        case .nexusJournalUnavailable:
            return "Account deletion is paused because the protected Nexus pending-transaction journal could not be verified. Recover the journal and try again. No wallet data was removed."
        case .polkamarktJournalUnavailable:
            return "Account deletion is paused because the protected Polkamarkt pending-transaction journal could not be verified. Recover the journal and try again. No wallet data was removed."
        case .sora2JournalUnavailable:
            return WalletUX.text(
                "The app could not read its list of recently sent transactions, so it can't tell whether one from this account is still being confirmed. Please try again in an hour. Nothing was removed."
            )
        case .unresolvedNexusTransaction:
            return "Account deletion is paused while a Minamoto or Taira transaction is unresolved. Wait for its final status and history reconciliation, then try again. No wallet data was removed."
        case .unresolvedPolkamarktTransaction:
            return "Account deletion is paused while a Polkamarkt transaction is unresolved. Wait for its final status, then try again. No wallet data was removed."
        case .unresolvedSora2Submission:
            return WalletUX.text(
                "A transaction from this account was sent a moment ago and is still being confirmed. This usually takes less than a minute and never more than an hour. Please try again shortly. Nothing was removed."
            )
        }
    }
}

enum WalletPendingDeletionPolicy {
    static func validate(
        nexusTransactions: [NexusPendingTransaction],
        polkamarktTransactions: [PolkamarktPendingMutation],
        sora2Submissions: [Sora2PendingSubmission] = [],
        walletId: String,
        soraAddress: String,
        now: Date = Date()
    ) throws {
        let hasUnresolvedNexusTransaction = nexusTransactions.contains {
            transaction in
            guard transaction.walletId == walletId else {
                return false
            }
            if transaction.state == .committed {
                return transaction.historyReconciledAt == nil
            }
            return !transaction.state.isTerminal
        }
        guard !hasUnresolvedNexusTransaction else {
            throw WalletPendingDeletionPreflightError
                .unresolvedNexusTransaction
        }

        guard !polkamarktTransactions.contains(where: {
            $0.account == soraAddress && !$0.state.isTerminal
        }) else {
            throw WalletPendingDeletionPreflightError
                .unresolvedPolkamarktTransaction
        }

        // Removal waits only while a transaction of this account may still
        // be entering the network. An entry that is resolved, found in a
        // finalized block, or older than its mortal era by a wide margin no
        // longer stands in the way, whether or not its result could be read.
        guard !sora2Submissions.contains(where: {
            $0.account == soraAddress &&
                $0.mayStillEnterChain(now: now)
        }) else {
            throw WalletPendingDeletionPreflightError
                .unresolvedSora2Submission
        }
    }
}

private final class WalletPendingDeletionPreflightOperation:
    PIAsyncOperation<Void>,
    @unchecked Sendable
{
    private let lifecycleOperation: BaseOperation<WalletLifecycleLease>
    private let walletId: String
    private let soraAddress: String

    init(
        lifecycleOperation: BaseOperation<WalletLifecycleLease>,
        walletId: String,
        soraAddress: String
    ) {
        self.lifecycleOperation = lifecycleOperation
        self.walletId = walletId
        self.soraAddress = soraAddress
    }

    override func execute() async throws {
        _ = try lifecycleOperation.extractNoCancellableResultData()
        try WalletRecoveryCapabilityGate.shared
            .requireAuthorizedLifecycleContinuation()

        let nexusTransactions: [NexusPendingTransaction]
        do {
            nexusTransactions = try await NexusPendingTransactionStore().all()
        } catch {
            throw WalletPendingDeletionPreflightError
                .nexusJournalUnavailable
        }

        let polkamarktTransactions: [PolkamarktPendingMutation]
        do {
            polkamarktTransactions = try await PolkamarktPendingStore().all()
        } catch {
            throw WalletPendingDeletionPreflightError
                .polkamarktJournalUnavailable
        }

        let sora2Submissions: [Sora2PendingSubmission]
        do {
            sora2Submissions = try Sora2PendingSubmissionStore().all()
        } catch {
            // Removal waits only for a transaction that may still be
            // entering the network, and such an entry was written within
            // the submission window. A journal that cannot be read and was
            // last written before that holds none, so it does not block
            // removal for good.
            guard Sora2PendingSubmissionStore
                .journalPredatesSubmissionWindow(now: Date())
            else {
                throw WalletPendingDeletionPreflightError
                    .sora2JournalUnavailable
            }
            sora2Submissions = []
        }

        try WalletPendingDeletionPolicy.validate(
            nexusTransactions: nexusTransactions,
            polkamarktTransactions: polkamarktTransactions,
            sora2Submissions: sora2Submissions,
            walletId: walletId,
            soraAddress: soraAddress
        )
    }
}

/// What an explicit, confirmed account removal may delete from the Keychain.
struct WalletExplicitRemovalPlan: Equatable {
    /// The account's own `<address>-*` items proved its address (or it is an
    /// explicit watch-only account without any). Only then are they removed
    /// with it. Otherwise the account is read-only here, and removing it
    /// removes only its account row and network entries; its items stay in
    /// the Keychain untouched.
    let removesOwnKeyMaterial: Bool
    /// The unsuffixed 1.x `seedEntropy` (with `userName`) derives exactly
    /// this account: sr25519, default path, no `-deriv` item, address and
    /// signature proven. Only that account can resolve through it, so only
    /// then is it removed with it.
    let removesRetainedLegacyEntropy: Bool

    static let keepKeychain = WalletExplicitRemovalPlan(
        removesOwnKeyMaterial: false, removesRetainedLegacyEntropy: false)
}

/// Pure identity/material policy used by the lifecycle-gated account deletion
/// flow and its retained-wallet regression tests. It performs no writes.
enum WalletExplicitRemovalIdentityPolicy {
    /// Whether removal also removes the global 1.x entropy (see
    /// `WalletExplicitRemovalPlan.removesRetainedLegacyEntropy`).
    static func verify(
        accounts: [AccountItem],
        expectedAccount: AccountItem,
        walletId: String,
        snapshot: WalletNetworkSnapshot,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws -> Bool {
        try plan(accounts: accounts, expectedAccount: expectedAccount, walletId: walletId,
                 snapshot: snapshot, keystore: keystore, settings: settings,
                 recoveryGate: recoveryGate).removesRetainedLegacyEntropy
    }

    static func plan(
        accounts: [AccountItem],
        expectedAccount: AccountItem,
        walletId: String,
        snapshot: WalletNetworkSnapshot,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws -> WalletExplicitRemovalPlan {
        let matchingAccounts = accounts.filter {
            $0.identifier == walletId
        }
        guard
            matchingAccounts.count == 1,
            let target = matchingAccounts.first,
            target.address == expectedAccount.address,
            target.publicKeyData == expectedAccount.publicKeyData,
            target.cryptoType == expectedAccount.cryptoType,
            target.networkType == expectedAccount.networkType,
            snapshot.schemaVersion == WalletNetworkSnapshot
                .currentSchemaVersion
        else {
            throw WalletNetworkMigrationError
                .explicitRemovalInventoryMismatch
        }

        let matchingWallets = snapshot.wallets.filter {
            $0.id == walletId
        }
        let matchingSoraAccounts = snapshot.accounts.filter {
            $0.walletId == walletId && $0.networkId == .sora2
        }
        guard
            matchingWallets.count == 1,
            let wallet = matchingWallets.first,
            wallet.existingSoraAddress == target.address,
            matchingSoraAccounts.count == 1,
            let soraAccount = matchingSoraAccounts.first,
            soraAccount.derivationVersion == 0,
            soraAccount.address == target.address,
            soraAccount.publicKey == target.publicKeyData
        else {
            throw WalletNetworkMigrationError
                .explicitRemovalInventoryMismatch
        }

        let watchOnlyKey = "wallet.watchOnly.\(target.address)"
        guard
            !settings.allKeys().contains(watchOnlyKey) ||
                settings.anyValue(for: watchOnlyKey) is Bool
        else {
            throw WalletNetworkMigrationError
                .legacyIdentityMismatch(target.address)
        }
        let isExplicitWatchOnly =
            settings.bool(for: watchOnlyKey) == true

        var secret = try keystore.fetchSecretKeyForAddress(
            target.address
        )
        var entropy: Data?
        do {
            entropy = try keystore.fetchEntropyForAddress(
                target.address,
                activeSnapshot: snapshot,
                recoveryGate: recoveryGate
            )
        } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
            // Retained global entropy that does not prove this account is not
            // its secret; it is never removed with it.
            entropy = nil
        }
        var rawSeed = try keystore.fetchSeedForAddress(
            target.address
        )
        let derivationPath = try keystore.fetchDeriviationForAddress(
            target.address
        )
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

        if wallet.secretSource == .watchOnly {
            guard
                isExplicitWatchOnly,
                secret == nil,
                entropy == nil,
                rawSeed == nil
            else {
                throw WalletNetworkMigrationError
                    .legacyIdentityMismatch(target.address)
            }
            try LegacySoraIdentityValidator.validate(
                address: target.address,
                publicKey: target.publicKeyData,
                cryptoType: target.cryptoType,
                networkType: target.networkType,
                derivationPath: derivationPath,
                entropy: nil,
                rawSeed: nil,
                secret: nil,
                recoveryGate: recoveryGate
            )
            return WalletExplicitRemovalPlan(removesOwnKeyMaterial: true, removesRetainedLegacyEntropy: false)
        }
        guard !isExplicitWatchOnly else {
            throw WalletNetworkMigrationError
                .legacyIdentityMismatch(target.address)
        }
        do {
            try Self.requireProvenSource(
                wallet.secretSource,
                target: target,
                entropy: entropy,
                rawSeed: rawSeed,
                secret: secret,
                derivationPath: derivationPath,
                recoveryGate: recoveryGate
            )
        } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
            // A read-only account (keys missing or not matching) can still
            // be removed on the user's confirmed request. Material that does
            // not prove it is quarantined: it stays in the Keychain, as do
            // the PIN and the global 1.x items.
            return .keepKeychain
        }
        return WalletExplicitRemovalPlan(
            removesOwnKeyMaterial: true,
            removesRetainedLegacyEntropy: try globalEntropyBelongsOnly(
                to: target,
                walletId: walletId,
                accounts: accounts,
                derivationPath: derivationPath,
                keystore: keystore,
                recoveryGate: recoveryGate
            )
        )
    }

    /// The global `seedEntropy` derives exactly one address: sr25519 with the
    /// default path. It belongs to `target` only when that address is the
    /// target's, proven with a signature. Equal bytes under another path or
    /// crypto type (the same phrase imported again) are not ownership.
    private static func globalEntropyBelongsOnly(
        to target: AccountItem,
        walletId: String,
        accounts: [AccountItem],
        derivationPath: String?,
        keystore: KeystoreProtocol,
        recoveryGate: WalletRecoveryCapabilityGate
    ) throws -> Bool {
        guard
            target.cryptoType == .sr25519,
            target.networkType == SNAddressType(chain: .sora),
            (derivationPath ?? "").isEmpty,
            try !keystore.checkKey(for: KeystoreTag.deriviationTagForAddress(target.address)),
            try keystore.checkKey(for: KeystoreTag.legacyEntropy.rawValue)
        else {
            return false
        }
        var global = try keystore.fetchKey(for: KeystoreTag.legacyEntropy.rawValue)
        defer { global.resetBytes(in: global.startIndex ..< global.endIndex) }
        guard WalletMnemonicWordPolicy.isDerivableEntropy(global) else { return false }
        do {
            try LegacySoraIdentityValidator.validate(
                address: target.address,
                publicKey: target.publicKeyData,
                cryptoType: .sr25519,
                networkType: target.networkType,
                derivationPath: nil,
                entropy: global,
                rawSeed: nil,
                secret: nil,
                recoveryGate: recoveryGate
            )
        } catch where LegacySoraIdentityValidator.isAccountIdentityFailure(error) {
            return false
        }
        // No remaining account may resolve through it. It derives only the
        // target's address, and addresses are unique, so this holds; it is
        // checked anyway.
        return !accounts.contains { $0.identifier != walletId && $0.address == target.address }
    }

    /// The Keychain part of a confirmed removal, as `plan` allows: the
    /// account's own items only when they proved it; the PIN only with the
    /// last account and only when that account's keys proved it (as before
    /// this release); the global `seedEntropy` and `userName` only when they
    /// derive exactly this account. Everything else is left untouched.
    static func removeKeychainItems(
        plan: WalletExplicitRemovalPlan,
        address: String,
        isLastAccount: Bool,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol
    ) throws {
        if plan.removesOwnKeyMaterial {
            try keystore.deleteWalletMaterial(for: address)
            if isLastAccount {
                try keystore.deleteKeysIfExist(for: [KeystoreTag.pincode.rawValue])
            }
        }
        if plan.removesRetainedLegacyEntropy {
            try keystore.deleteKeysIfExist(
                for: [
                    KeystoreTag.legacyEntropy.rawValue,
                    KeystoreTag.legacyUsername.rawValue,
                ]
            )
            settings.removeValue(
                for: KeystoreTag.legacyUsername.rawValue
            )
            guard
                settings.anyValue(
                    for: KeystoreTag.legacyUsername.rawValue
                ) == nil
            else {
                throw WalletNetworkMigrationError
                    .explicitRemovalInventoryMismatch
            }
        }
    }

    private static func requireProvenSource(
        _ source: WalletSecretSource,
        target: AccountItem,
        entropy: Data?,
        rawSeed: Data?,
        secret: Data?,
        derivationPath: String?,
        recoveryGate: WalletRecoveryCapabilityGate
    ) throws {
        switch source {
        case .watchOnly, .signingUnavailable:
            throw WalletNetworkMigrationError.legacyIdentityMismatch(target.address)
        case .mnemonicEntropy, .legacyMnemonicEntropy:
            guard let entropy else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(target.address)
            }
            let wordCount = try IRMnemonicCreator(language: .english)
                .mnemonic(fromEntropy: entropy)
                .allWords()
                .count
            guard WalletMnemonicWordPolicy.retainedSecretSource(forWordCount: wordCount) == source else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(target.address)
            }
        case .rawSeed:
            guard rawSeed != nil, entropy.map({ !WalletMnemonicWordPolicy.isDerivableEntropy($0) }) ?? true else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(target.address)
            }
        case .legacySecret:
            guard rawSeed == nil, secret != nil, entropy.map({ !WalletMnemonicWordPolicy.isDerivableEntropy($0) }) ?? true else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(target.address)
            }
        }
        try LegacySoraIdentityValidator.validate(
            address: target.address,
            publicKey: target.publicKeyData,
            cryptoType: target.cryptoType,
            networkType: target.networkType,
            derivationPath: derivationPath,
            entropy: entropy,
            rawSeed: rawSeed,
            secret: secret,
            recoveryGate: recoveryGate
        )
    }
}

extension AccountOptionsInteractor: EventVisitorProtocol {}

private extension AccountOptionsInteractor {

    /// Decides what the confirmed removal may delete. Only material that
    /// proves the installed SORA2 identity is removed with the account. For a
    /// read-only account (keys missing or not matching) only the account row
    /// and its network entries are removed; its Keychain items, the PIN and
    /// the global 1.x items stay. Unreadable material (a Keychain error)
    /// throws, and nothing is removed.
    ///
    /// The unsuffixed `seedEntropy` is removed only when it derives exactly
    /// this account, after this proof and the explicit-removal journal commit.
    func verifyExplicitRemovalIdentity(
        accounts: [AccountItem],
        walletId: String
    ) throws -> WalletExplicitRemovalPlan {
        try WalletRecoveryCapabilityGate.shared
            .requireAuthorizedLifecycleContinuation()
        guard let snapshot = try WalletNetworkStore().load() else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let plan = try WalletExplicitRemovalIdentityPolicy.plan(
            accounts: accounts,
            expectedAccount: account,
            walletId: walletId,
            snapshot: snapshot,
            keystore: keystore,
            settings: settings
        )
        _ = try MigrationAccountCompletionStore.contains(
            accountAddress: account.address,
            settings: settings
        )
        return plan
    }

    func verifyAndCommitExplicitRemovalMetadata(
        accounts: [AccountItem],
        networkSnapshot: WalletNetworkSnapshot,
        removedWalletId: String
    ) throws -> AccountItem? {
        try WalletRecoveryCapabilityGate.shared
            .requireAuthorizedLifecycleContinuation()
        guard try WalletNetworkStore().load() == networkSnapshot else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let selectedAccount = try verifyExplicitRemovalState(
            accounts: accounts,
            removedWalletId: removedWalletId,
            selectedWalletId: networkSnapshot.selectedWalletId
        )
        let selectedAccountKey = SettingsKey.selectedAccount.rawValue
        if let selectedAccount {
            let encodedSelectedAccount = try JSONEncoder().encode(
                selectedAccount
            )
            settings.set(
                value: encodedSelectedAccount,
                for: selectedAccountKey
            )
            guard
                settings.data(for: selectedAccountKey) ==
                    encodedSelectedAccount
            else {
                throw WalletNetworkMigrationError
                    .explicitRemovalSelectionMismatch
            }
        } else {
            settings.removeValue(for: selectedAccountKey)
            guard settings.anyValue(for: selectedAccountKey) == nil else {
                throw WalletNetworkMigrationError
                    .explicitRemovalSelectionMismatch
            }
        }
        return selectedAccount
    }

    @discardableResult
    func verifyExplicitRemovalState(
        accounts: [AccountItem],
        removedWalletId: String,
        selectedWalletId: String?
    ) throws -> AccountItem? {
        let accountIds = accounts.map(\.identifier)
        guard
            Set(accountIds).count == accountIds.count,
            !accountIds.contains(removedWalletId),
            let activeSnapshot = try WalletNetworkStore().load(),
            !activeSnapshot.wallets.contains(where: {
                $0.id == removedWalletId
            }),
            !activeSnapshot.accounts.contains(where: {
                $0.walletId == removedWalletId
            }),
            Set(activeSnapshot.wallets.map(\.id)) == Set(accountIds),
            activeSnapshot.selectedWalletId == selectedWalletId
        else {
            throw WalletNetworkMigrationError
                .explicitRemovalInventoryMismatch
        }
        let selectedAccounts = accounts.filter(\.isSelected)
        if accounts.isEmpty {
            guard
                selectedWalletId == nil,
                selectedAccounts.isEmpty
            else {
                throw WalletNetworkMigrationError
                    .explicitRemovalSelectionMismatch
            }
            return nil
        }
        guard
            selectedAccounts.count == 1,
            let selectedAccount = selectedAccounts.first,
            selectedAccount.identifier == selectedWalletId
        else {
            throw WalletNetworkMigrationError
                .explicitRemovalSelectionMismatch
        }
        return selectedAccount
    }

    func finishExplicitRemoval(
        accounts: [AccountItem],
        lifecycleLease: WalletLifecycleLease,
        plan: WalletExplicitRemovalPlan
    ) {
        do {
            try WalletRecoveryCapabilityGate.shared
                .requireAuthorizedLifecycleContinuation()
        } catch {
            enterDeletionRecovery(
                error,
                lifecycleLease: lifecycleLease
            )
            return
        }
        let backupedAddresses =
            ApplicationConfig.shared.backupedAccountAddresses
        ApplicationConfig.shared.backupedAccountAddresses =
            backupedAddresses.filter {
                $0 != account.address
            }

        guard !accounts.isEmpty else {
            cleanData(lifecycleLease: lifecycleLease, plan: plan)
            return
        }
        do {
            try cleanKeystore(
                leavingPin: true,
                plan: plan
            )
        } catch {
            enterDeletionRecovery(
                error,
                lifecycleLease: lifecycleLease
            )
            return
        }
        lifecycleLease.release()
        let selectionEventCenter = eventCenter
        DispatchQueue.main.async { [weak self] in
            selectionEventCenter.notify(
                with: SelectedAccountChanged(),
                completionOnMain: { [weak self] in
                    self?.presenter.close()
                }
            )
        }
    }

    func enterDeletionRecovery(
        _ error: Error,
        lifecycleLease: WalletLifecycleLease? = nil
    ) {
        settings.setWalletMigrationRecovery(
            reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
        )
        lifecycleLease?.release()
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.restart()
        }
    }

    /// Removes what `plan` allows. The account's own items go only when they
    /// proved it; the global `seedEntropy` and `userName` only when they
    /// derive exactly this account; the PIN only with the last account, and
    /// only when that account's keys proved it (as before this release).
    /// Unproven material is left in the Keychain untouched.
    func cleanKeystore(
        leavingPin: Bool = true,
        plan: WalletExplicitRemovalPlan
    ) throws {
        try WalletRecoveryCapabilityGate.shared
            .requireAuthorizedLifecycleContinuation()
        let address = account.address
        try WalletExplicitRemovalIdentityPolicy.removeKeychainItems(
            plan: plan,
            address: address,
            isLastAccount: !leavingPin,
            keystore: keystore,
            settings: settings
        )
        if leavingPin {
            try MigrationAccountCompletionStore.remove(
                accountAddress: address,
                settings: settings
            )
            let watchOnlyKey = "wallet.watchOnly.\(address)"
            settings.removeValue(for: watchOnlyKey)
            guard settings.anyValue(for: watchOnlyKey) == nil else {
                throw WalletNetworkMigrationError
                    .explicitRemovalInventoryMismatch
            }
        }
    }

    func stopServices() {
        ServiceCoordinator.shared.throttle()
    }

    func cleanSettings() throws {
        try WalletRecoveryCapabilityGate.shared
            .requireAuthorizedLifecycleContinuation()
        settings.removeAll()
    }

    func cleanCoreData() throws {
        try WalletRecoveryCapabilityGate.shared
            .requireAuthorizedLifecycleContinuation()
        try? cacheFacade.databaseService.close()
        try? cacheFacade.databaseService.drop()

        try? substrateDataFacade.databaseService.close()
        try? substrateDataFacade.databaseService.drop()

        try? userDataFacade.databaseService.close()
        try? userDataFacade.databaseService.drop()
    }

    func cleanData(lifecycleLease: WalletLifecycleLease, plan: WalletExplicitRemovalPlan) {
        // The user explicitly confirmed deletion of the final account. Its
        // proven keys and the PIN go with it; anything not proven to belong
        // to it stays in the Keychain (the next launch offers Welcome back).
        do {
            try cleanKeystore(leavingPin: false, plan: plan)
            try cleanSettings()
            try cleanCoreData()
        } catch {
            enterDeletionRecovery(
                error,
                lifecycleLease: lifecycleLease
            )
            return
        }
        stopServices()
        lifecycleLease.release()
        // TODO: [SN-377] Clean Capital cache
        DispatchQueue.main.async {
            self.presenter?.restart()
        }
    }

    func getAccounts(with completion: @escaping ([AccountItem]) -> Void) {
        let persistentOperation = accountRepository.fetchAllOperation(with: .none)

        persistentOperation.completionBlock = {
            guard let accounts = try? persistentOperation.extractNoCancellableResultData() else { return }
            completion(accounts)
        }

        operationManager.enqueue(operations: [persistentOperation], in: .transient)
    }
}
