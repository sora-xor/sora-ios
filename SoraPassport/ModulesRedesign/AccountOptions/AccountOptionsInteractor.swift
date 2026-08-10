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
        guard let entropy = try keystore.fetchEntropyForAddress(account.address) else { return nil }
        let mnemonic = try mnemonicCreator.mnemonic(fromEntropy: entropy)
        return mnemonic
    }
}

extension AccountOptionsInteractor: AccountOptionsInteractorInputProtocol {

    var currentAccount: AccountItem {
        account
    }

    var accountHasEntropy: Bool {
        guard let result = try? keystore.checkEntropyForAddress(account.address) else { return false }
        return result

    }

    func getMetadata() -> AccountCreationMetadata? {
        guard let mnemonic = try? loadPhrase() else { return nil }
        
        let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                               availableNetworks: Chain.allCases,
                                               defaultNetwork: .sora,
                                               availableCryptoTypes: CryptoType.allCases,
                                               defaultCryptoType: .sr25519)
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
                                            cryptoType: metadata?.defaultCryptoType.typeString ?? "SR25519",
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
        let identityPreflightOperation: BaseOperation<Bool> =
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
                let removesRetainedLegacyEntropy =
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
                        removesRetainedLegacyEntropy:
                            removesRetainedLegacyEntropy
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
                            removesRetainedLegacyEntropy:
                                removesRetainedLegacyEntropy
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
            return "Account deletion is paused because the protected SORA2 signed-submission journal could not be verified. Recover the journal and try again. No wallet data was removed."
        case .unresolvedNexusTransaction:
            return "Account deletion is paused while a Minamoto or Taira transaction is unresolved. Wait for its final status and history reconciliation, then try again. No wallet data was removed."
        case .unresolvedPolkamarktTransaction:
            return "Account deletion is paused while a Polkamarkt transaction is unresolved. Wait for its final status, then try again. No wallet data was removed."
        case .unresolvedSora2Submission:
            return "Account deletion is paused while a signed SORA2 transaction may still be entering the network. Wait for submission reconciliation, then try again. No wallet data was removed."
        }
    }
}

enum WalletPendingDeletionPolicy {
    static func validate(
        nexusTransactions: [NexusPendingTransaction],
        polkamarktTransactions: [PolkamarktPendingMutation],
        sora2Submissions: [Sora2PendingSubmission] = [],
        walletId: String,
        soraAddress: String
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

        guard !sora2Submissions.contains(where: {
            $0.account == soraAddress &&
                !$0.isPrunable
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
            throw WalletPendingDeletionPreflightError
                .sora2JournalUnavailable
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

/// Pure identity/material policy used by the lifecycle-gated account deletion
/// flow and its retained-wallet regression tests. It performs no writes.
enum WalletExplicitRemovalIdentityPolicy {
    static func verify(
        accounts: [AccountItem],
        expectedAccount: AccountItem,
        walletId: String,
        snapshot: WalletNetworkSnapshot,
        keystore: KeystoreProtocol,
        settings: SettingsManagerProtocol,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) throws -> Bool {
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

        let hasScopedEntropy = try keystore.checkKey(
            for: KeystoreTag.entropyTagForAddress(target.address)
        )
        var secret = try keystore.fetchSecretKeyForAddress(
            target.address
        )
        var entropy = try keystore.fetchEntropyForAddress(
            target.address,
            activeSnapshot: snapshot
        )
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

        switch wallet.secretSource {
        case .watchOnly:
            guard
                isExplicitWatchOnly,
                secret == nil,
                entropy == nil,
                rawSeed == nil
            else {
                throw WalletNetworkMigrationError
                    .legacyIdentityMismatch(target.address)
            }
        case .mnemonicEntropy, .legacyMnemonicEntropy:
            guard
                !isExplicitWatchOnly,
                let entropy
            else {
                throw WalletNetworkMigrationError
                    .legacyIdentityMismatch(target.address)
            }
            let wordCount = try IRMnemonicCreator(language: .english)
                .mnemonic(fromEntropy: entropy)
                .allWords()
                .count
            guard
                WalletMnemonicWordPolicy.retainedSecretSource(
                    forWordCount: wordCount
                ) == wallet.secretSource
            else {
                throw WalletNetworkMigrationError
                    .legacyIdentityMismatch(target.address)
            }
        case .rawSeed:
            guard
                !isExplicitWatchOnly,
                entropy == nil,
                rawSeed != nil
            else {
                throw WalletNetworkMigrationError
                    .legacyIdentityMismatch(target.address)
            }
        case .legacySecret:
            guard
                !isExplicitWatchOnly,
                entropy == nil,
                rawSeed == nil,
                secret != nil
            else {
                throw WalletNetworkMigrationError
                    .legacyIdentityMismatch(target.address)
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

        let hasLegacyEntropy = try keystore.checkKey(
            for: KeystoreTag.legacyEntropy.rawValue
        )
        return !hasScopedEntropy && entropy != nil && hasLegacyEntropy
    }
}

extension AccountOptionsInteractor: EventVisitorProtocol {}

private extension AccountOptionsInteractor {

    /// Proves that the exact protected material about to be deleted still
    /// derives the installed SORA2 identity. Missing or unreadable material is
    /// a recovery condition, never permission to remove an account.
    ///
    /// The return value identifies the oldest supported layout, where the
    /// wallet owns the single unsuffixed `seedEntropy` tag. Cleanup may remove
    /// that tag only after this proof and the explicit-removal journal commit.
    func verifyExplicitRemovalIdentity(
        accounts: [AccountItem],
        walletId: String
    ) throws -> Bool {
        try WalletRecoveryCapabilityGate.shared
            .requireAuthorizedLifecycleContinuation()
        guard let snapshot = try WalletNetworkStore().load() else {
            throw WalletNetworkMigrationError.snapshotVerificationFailed
        }
        let removesRetainedLegacyEntropy =
            try WalletExplicitRemovalIdentityPolicy.verify(
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
        return removesRetainedLegacyEntropy
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
        removesRetainedLegacyEntropy: Bool
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
            cleanData(lifecycleLease: lifecycleLease)
            return
        }
        do {
            try cleanKeystore(
                leavingPin: true,
                removesRetainedLegacyEntropy:
                    removesRetainedLegacyEntropy
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
        settings.walletMigrationRecoveryRequired = true
        settings.walletMigrationRecoveryReason =
            UserStorageMigrationError
                .privacySafeRecoveryDescription(for: error)
        lifecycleLease?.release()
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.restart()
        }
    }

    func cleanKeystore(
        leavingPin: Bool = true,
        removesRetainedLegacyEntropy: Bool = false
    ) throws {
        try WalletRecoveryCapabilityGate.shared
            .requireAuthorizedLifecycleContinuation()
        let address = account.address
        if leavingPin {
            try keystore.deleteWalletMaterial(for: address)
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
            if removesRetainedLegacyEntropy {
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
        } else {
            try keystore.deleteAll(for: address)
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

    func cleanData(lifecycleLease: WalletLifecycleLease) {
        // The user explicitly confirmed deletion of the final account, so
        // clearing its PIN/global legacy import keys is intentional here.
        do {
            try cleanKeystore(leavingPin: false)
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
