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

protocol SelectedWalletSettingsProtocol: AnyObject {
    var currentAccount: AccountItem? { get }
    func performSave(
        value: AccountItem,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    )
    func performInsertAndSelect(
        prepared: PreparedAccount,
        persistSecrets: @escaping () throws -> Void,
        lifecycleLease: WalletLifecycleLease,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    )
    func performSelectAfterRemoval(
        value: AccountItem,
        lifecycleLease: WalletLifecycleLease,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    )
    /// Updates account metadata without changing the durable selected wallet.
    /// This is used for names and asset preferences so a stale screen cannot
    /// switch accounts while another lifecycle mutation is being committed.
    func performUpdateName(
        account: AccountItem,
        displayName: String,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    )
    func performUpdateAssetSettings(
        account: AccountItem,
        settings: AccountSettings,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    )
    func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void)
    func save(value: AccountItem)
}

enum SelectedWalletSettingsError: LocalizedError {
    case duplicateAccountIdentifiers
    case multipleSelectedAccounts
    case missingSelectedAccount

    var errorDescription: String? {
        switch self {
        case .duplicateAccountIdentifiers:
            return "The wallet database contains duplicate account identifiers."
        case .multipleSelectedAccounts:
            return "The wallet database contains more than one selected account."
        case .missingSelectedAccount:
            return "Existing wallet accounts were found, but no verified selected account is available."
        }
    }
}

private struct PreparedWalletInsertCommit {
    let journal: WalletAccountCommitJournal
    let accountsToSave: [ManagedAccountItem]
    let selectedAccount: AccountItem
}

private enum WalletAccountMetadataMutation {
    case displayName(String)
    case assetSettings(AccountSettings)
}

final class SelectedWalletSettings: PersistentValueSettings<AccountItem>, SelectedWalletSettingsProtocol {
    static let shared = SelectedWalletSettings(
        storageFacade: UserDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue,
        legacySettings: SettingsManager.shared,
        walletNetworkSynchronizer: {
            accounts,
            selectedAddress,
            lifecycleLease in
            do {
                try WalletNetworkModelMigrator(
                    keystore: Keychain(),
                    store: WalletNetworkStore(),
                    settings: SettingsManager.shared
                ).migrate(
                    accounts: accounts,
                    selectedAddress: selectedAddress,
                    lifecycleLease: lifecycleLease
                )
            } catch {
                SettingsManager.shared.setWalletMigrationRecovery(
                    reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
                )
                throw error
            }
        },
        walletNetworkSelectionSynchronizer: {
            accounts,
            selectedAddress,
            lifecycleLease in
            do {
                try WalletLifecycleCoordinator.shared.withExclusiveAccess(
                    using: lifecycleLease
                ) {
                    try WalletNetworkStore().selectWallet(
                        walletId: selectedAddress,
                        expectedAccounts: accounts
                    )
                }
            } catch {
                SettingsManager.shared.setWalletMigrationRecovery(
                    reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
                )
                throw error
            }
        },
        walletNetworkMetadataSynchronizer: {
            accounts,
            walletId,
            displayName,
            lifecycleLease in
            do {
                try WalletLifecycleCoordinator.shared.withExclusiveAccess(
                    using: lifecycleLease
                ) {
                    try WalletNetworkStore().updateWalletDisplayName(
                        walletId: walletId,
                        displayName: displayName,
                        expectedAccounts: accounts
                    )
                }
            } catch {
                SettingsManager.shared.setWalletMigrationRecovery(
                    reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
                )
                throw error
            }
        }
    )

    let operationQueue: OperationQueue
    private let legacySettings: SettingsManagerProtocol?
    private let walletNetworkSynchronizer:
        (([AccountItem], String, WalletLifecycleLease) throws -> Void)?
    private let walletNetworkSelectionSynchronizer:
        (([AccountItem], String, WalletLifecycleLease) throws -> Void)?
    private let walletNetworkMetadataSynchronizer:
        ((
            [AccountItem],
            String,
            String,
            WalletLifecycleLease
        ) throws -> Void)?
    private let walletAccountCommitJournalStoreFactory:
        () throws -> WalletAccountCommitJournalStore
    private let lifecycleCoordinator: WalletLifecycleCoordinator
    private let recoveryGate: WalletRecoveryCapabilityGate

    init(
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        legacySettings: SettingsManagerProtocol? = nil,
        walletNetworkSynchronizer:
            (([AccountItem], String, WalletLifecycleLease) throws -> Void)? = nil,
        walletNetworkSelectionSynchronizer:
            (([AccountItem], String, WalletLifecycleLease) throws -> Void)? = nil,
        walletNetworkMetadataSynchronizer:
            ((
                [AccountItem],
                String,
                String,
                WalletLifecycleLease
            ) throws -> Void)? = nil,
        walletAccountCommitJournalStoreFactory:
            @escaping () throws -> WalletAccountCommitJournalStore = {
                try WalletAccountCommitJournalStore()
            },
        lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
        recoveryGate: WalletRecoveryCapabilityGate = .shared
    ) {
        self.operationQueue = operationQueue
        self.legacySettings = legacySettings
        self.walletNetworkSynchronizer = walletNetworkSynchronizer
        self.walletNetworkSelectionSynchronizer =
            walletNetworkSelectionSynchronizer
        self.walletNetworkMetadataSynchronizer =
            walletNetworkMetadataSynchronizer
        self.walletAccountCommitJournalStoreFactory =
            walletAccountCommitJournalStoreFactory
        self.lifecycleCoordinator = lifecycleCoordinator
        self.recoveryGate = recoveryGate

        super.init(storageFacade: storageFacade)
    }

    override func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void) {
        let mapper = AccountItemMapper()

        let repository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let operation = repository.fetchAllOperation(with: options)

        operation.completionBlock = {
            do {
                let accounts = try operation.extractNoCancellableResultData()
                let legacySelectedAddress = self.legacySettings?.value(
                    of: AccountItem.self,
                    for: SettingsKey.selectedAccount.rawValue
                )?.identifier
                completionClosure(
                    .success(
                        try Self.resolveSelection(
                            accounts: accounts,
                            legacySelectedAddress: legacySelectedAddress
                        )
                    )
                )
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperation(operation)
    }

    static func resolveSelection(
        accounts: [AccountItem],
        legacySelectedAddress: String?
    ) throws -> AccountItem? {
        guard Set(accounts.map(\.identifier)).count == accounts.count else {
            throw SelectedWalletSettingsError.duplicateAccountIdentifiers
        }
        let selectedAccounts = accounts.filter(\.isSelected)
        guard selectedAccounts.count <= 1 else {
            throw SelectedWalletSettingsError.multipleSelectedAccounts
        }
        if let selected = selectedAccounts.first {
            // Core Data is authoritative after version 2. The retained
            // UserDefaults value may legitimately be stale after a later
            // account switch.
            return selected
        }
        guard !accounts.isEmpty else {
            guard legacySelectedAddress == nil else {
                throw SelectedWalletSettingsError.missingSelectedAccount
            }
            return nil
        }
        guard
            let legacySelectedAddress,
            let legacySelected = accounts.first(where: {
                $0.identifier == legacySelectedAddress
            })
        else {
            throw SelectedWalletSettingsError.missingSelectedAccount
        }
        return legacySelected
    }

    override func performSave(
        value: AccountItem,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    ) {
        performSave(
            value: value,
            suppliedLifecycleLease: nil,
            requiresFullIdentitySynchronization: false,
            completionClosure: completionClosure
        )
    }

    override func save(
        value: AccountItem,
        runningCompletionIn queue: DispatchQueue?,
        completionClosure: ((Result<AccountItem, Error>) -> Void)?
    ) {
        // performSave commits the selection while holding its lifecycle lease.
        // Do not repeat that write after the lease has been released: another
        // queued selection may already have committed a newer value.
        performSave(value: value) { result in
            if let completionClosure {
                dispatchInQueueWhenPossible(queue) {
                    completionClosure(result)
                }
            }
        }
    }

    func performInsertAndSelect(
        prepared: PreparedAccount,
        persistSecrets: @escaping () throws -> Void,
        lifecycleLease: WalletLifecycleLease,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    ) {
        let value = prepared.account
        let mapper = ManagedAccountItemMapper()
        let repository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )
        let options = RepositoryFetchOptions(
            includesProperties: true,
            includesSubentities: true
        )
        let lifecycleCoordinator = self.lifecycleCoordinator
        let recoveryGate = self.recoveryGate
        let lifecycleOperation =
            lifecycleCoordinator.makeAcquireOperation(
                using: lifecycleLease
            )
        let walletAccountCommitJournalStoreFactory =
            self.walletAccountCommitJournalStoreFactory
        let accountsOperation = repository.fetchAllOperation(with: options)
        accountsOperation.addDependency(lifecycleOperation)

        let prepareOperation:
            BaseOperation<PreparedWalletInsertCommit> = ClosureOperation {
                _ = try lifecycleOperation
                    .extractNoCancellableResultData()
                try recoveryGate
                    .requireAuthorizedLifecycleContinuation()
                let accounts = try accountsOperation
                    .extractNoCancellableResultData()
                guard
                    Set(accounts.map(\.address)).count == accounts.count,
                    !accounts.contains(where: {
                        $0.address == value.address
                    })
                else {
                    throw AccountCreateError.duplicated
                }
                let selectedAccounts = accounts.filter(\.isSelected)
                guard
                    (accounts.isEmpty && selectedAccounts.isEmpty) ||
                        selectedAccounts.count == 1
                else {
                    throw selectedAccounts.isEmpty
                        ? SelectedWalletSettingsError.missingSelectedAccount
                        : SelectedWalletSettingsError
                            .multipleSelectedAccounts
                }
                let nextOrder: Int16
                if let maximumOrder = accounts.map(\.order).max() {
                    guard maximumOrder < Int16.max else {
                        throw WalletNetworkMigrationError
                            .snapshotVerificationFailed
                    }
                    nextOrder = maximumOrder + 1
                } else {
                    nextOrder = 0
                }
                let selectedAccount = AccountItem(
                    address: value.address,
                    cryptoType: value.cryptoType,
                    networkType: value.networkType,
                    username: value.username,
                    publicKeyData: value.publicKeyData,
                    settings: value.settings,
                    order: nextOrder,
                    isSelected: true
                )
                let journalStore =
                    try walletAccountCommitJournalStoreFactory()
                var journal = try journalStore.begin(
                    walletId: value.address,
                    existingWalletIds: accounts.map(\.address)
                )
                RetainedMigrationEvidenceHarness.shared.checkpoint(
                    .beforeSecretRetention
                )
                try persistSecrets()
                journal = try journalStore.advance(
                    journal,
                    to: .secretsPersisted
                )
                RetainedMigrationEvidenceHarness.shared.checkpoint(
                    .afterSecretRetention
                )
                var accountsToSave = accounts.compactMap {
                    account -> ManagedAccountItem? in
                    guard account.isSelected else {
                        return nil
                    }
                    return ManagedAccountItem(
                        address: account.address,
                        cryptoType: account.cryptoType,
                        networkType: account.networkType,
                        username: account.username,
                        publicKeyData: account.publicKeyData,
                        order: account.order,
                        settings: account.settings,
                        isSelected: false
                    )
                }
                accountsToSave.append(
                    ManagedAccountItem(
                        address: selectedAccount.address,
                        cryptoType: selectedAccount.cryptoType,
                        networkType: selectedAccount.networkType,
                        username: selectedAccount.username,
                        publicKeyData: selectedAccount.publicKeyData,
                        order: selectedAccount.order,
                        settings: selectedAccount.settings,
                        isSelected: true
                    )
                )
                return PreparedWalletInsertCommit(
                    journal: journal,
                    accountsToSave: accountsToSave,
                    selectedAccount: selectedAccount
                )
            }
        prepareOperation.addDependency(accountsOperation)

        let saveOperation = repository.saveOperation({
            try recoveryGate
                .requireAuthorizedLifecycleContinuation()
            return try prepareOperation.extractNoCancellableResultData()
                .accountsToSave
        }, { [] })
        saveOperation.addDependency(prepareOperation)
        let verifyOperation = repository.fetchAllOperation(with: options)
        verifyOperation.addDependency(saveOperation)

        let walletNetworkSynchronizer = walletNetworkSynchronizer
        verifyOperation.completionBlock = { [weak self] in
            do {
                _ = try lifecycleOperation
                    .extractNoCancellableResultData()
                _ = try saveOperation.extractNoCancellableResultData()
                try recoveryGate
                    .requireAuthorizedLifecycleContinuation()
                let preparedCommit = try prepareOperation
                    .extractNoCancellableResultData()
                let accounts = try verifyOperation
                    .extractNoCancellableResultData()
                    .map(AccountItem.init(managedItem:))
                guard
                    accounts.filter(\.isSelected) ==
                        [preparedCommit.selectedAccount],
                    Set(accounts.map(\.address)).count == accounts.count,
                    Set(accounts.map(\.address)) ==
                        Set(
                            preparedCommit.journal
                                .expectedExistingWalletIds +
                                [preparedCommit.selectedAccount.address]
                        )
                else {
                    throw WalletNetworkMigrationError
                        .snapshotVerificationFailed
                }
                let journalStore =
                    try walletAccountCommitJournalStoreFactory()
                var journal = try journalStore.advance(
                    preparedCommit.journal,
                    to: .coreDataCommitted
                )
                RetainedMigrationEvidenceHarness.shared.checkpoint(
                    .afterCoreDataCommit
                )
                try walletNetworkSynchronizer?(
                    accounts,
                    preparedCommit.selectedAccount.address,
                    lifecycleLease
                )
                journal = try journalStore.advance(
                    journal,
                    to: .networkModelActivated
                )
                if let legacySettings = self?.legacySettings {
                    legacySettings.set(
                        value: preparedCommit.selectedAccount,
                        for: SettingsKey.selectedAccount.rawValue
                    )
                    guard
                        legacySettings.value(
                            of: AccountItem.self,
                            for: SettingsKey.selectedAccount.rawValue
                        ) == preparedCommit.selectedAccount
                    else {
                        throw WalletNetworkMigrationError
                            .snapshotVerificationFailed
                    }
                }
                _ = try journalStore.advance(
                    journal,
                    to: .activated
                )
                self?.commitInternalValue(
                    preparedCommit.selectedAccount
                )
                completionClosure(
                    .success(preparedCommit.selectedAccount)
                )
            } catch {
                prepared.discard()
                let hasUnresolvedCommit =
                    (
                        try? walletAccountCommitJournalStoreFactory()
                            .unresolved()
                            .contains(where: {
                                $0.walletId == value.address
                            })
                    ) == true
                if hasUnresolvedCommit {
                    self?.legacySettings?.setWalletMigrationRecovery(
                        reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
                    )
                }
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperations(
            [
                lifecycleOperation,
                accountsOperation,
                prepareOperation,
                saveOperation,
                verifyOperation,
            ],
            waitUntilFinished: false
        )
    }

    func performSelectAfterRemoval(
        value: AccountItem,
        lifecycleLease: WalletLifecycleLease,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    ) {
        performSave(
            value: value,
            suppliedLifecycleLease: lifecycleLease,
            requiresFullIdentitySynchronization: false,
            completionClosure: completionClosure
        )
    }

    private func performSave(
        value: AccountItem,
        suppliedLifecycleLease: WalletLifecycleLease?,
        requiresFullIdentitySynchronization: Bool,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    ) {
        let mapper = ManagedAccountItemMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let accountsOperation = repository.fetchAllOperation(with: options)
        let lifecycleCoordinator = self.lifecycleCoordinator
        let recoveryGate = self.recoveryGate
        let lifecycleOperation = lifecycleCoordinator.makeAcquireOperation(
            using: suppliedLifecycleLease
        )
        accountsOperation.addDependency(lifecycleOperation)
        let walletNetworkSynchronizer = walletNetworkSynchronizer
        let walletNetworkSelectionSynchronizer =
            walletNetworkSelectionSynchronizer

        let saveOperation = repository.saveOperation({
            _ = try lifecycleOperation
                .extractNoCancellableResultData()
            try recoveryGate
                .requireAuthorizedLifecycleContinuation()
            let accounts = try accountsOperation.extractNoCancellableResultData()
            guard Set(accounts.map(\.address)).count == accounts.count else {
                throw SelectedWalletSettingsError.duplicateAccountIdentifiers
            }
            guard
                let existingAccount = accounts.first(where: {
                    $0.address == value.address
                })
            else {
                // Selection is never an insertion path. A stale screen must
                // not recreate a wallet whose explicit deletion completed
                // while it waited for the lifecycle lease.
                throw WalletNetworkMigrationError
                    .explicitRemovalTargetMissing(value.address)
            }
            let selectedAccounts = accounts.filter(\.isSelected)
            let isFirstWalletInsertion =
                requiresFullIdentitySynchronization &&
                accounts.count == 1 &&
                selectedAccounts.isEmpty &&
                !existingAccount.isSelected
            guard
                selectedAccounts.count == 1 ||
                    isFirstWalletInsertion
            else {
                throw selectedAccounts.isEmpty
                    ? SelectedWalletSettingsError.missingSelectedAccount
                    : SelectedWalletSettingsError.multipleSelectedAccounts
            }

            var accountsToSave: [ManagedAccountItem] = accounts.compactMap {
                account -> ManagedAccountItem? in
                guard
                    account.isSelected,
                    account.address != value.address
                else {
                    return nil
                }
                return ManagedAccountItem(
                    address: account.address,
                    cryptoType: account.cryptoType,
                    networkType: account.networkType,
                    username: account.username,
                    publicKeyData: account.publicKeyData,
                    order: account.order,
                    settings: account.settings,
                    isSelected: false
                )
            }
            accountsToSave.append(
                ManagedAccountItem(
                    address: existingAccount.address,
                    cryptoType: existingAccount.cryptoType,
                    networkType: existingAccount.networkType,
                    username: existingAccount.username,
                    publicKeyData: existingAccount.publicKeyData,
                    order: existingAccount.order,
                    settings: existingAccount.settings,
                    isSelected: true
                )
            )

            return accountsToSave
        }, { [] })

        saveOperation.addDependency(accountsOperation)

        saveOperation.completionBlock = { [weak self] in
            var acquiredLease: WalletLifecycleLease?
            let completionResult: Result<AccountItem, Error>
            do {
                let lifecycleLease = try lifecycleOperation
                    .extractNoCancellableResultData()
                acquiredLease = lifecycleLease
                _ = try saveOperation.extractNoCancellableResultData()
                try recoveryGate
                    .requireAuthorizedLifecycleContinuation()
                let previousAccounts =
                    try accountsOperation.extractNoCancellableResultData()
                guard
                    let existingAccount = previousAccounts.first(where: {
                        $0.address == value.address
                    })
                else {
                    throw WalletNetworkMigrationError
                        .explicitRemovalTargetMissing(value.address)
                }
                var synchronizedAccounts = previousAccounts
                    .filter { $0.address != value.address }
                    .map {
                        AccountItem(
                            address: $0.address,
                            cryptoType: $0.cryptoType,
                            networkType: $0.networkType,
                            username: $0.username,
                            publicKeyData: $0.publicKeyData,
                            settings: $0.settings,
                            order: $0.order,
                            isSelected: false
                        )
                    }
                synchronizedAccounts.append(
                    AccountItem(
                        address: existingAccount.address,
                        cryptoType: existingAccount.cryptoType,
                        networkType: existingAccount.networkType,
                        username: existingAccount.username,
                        publicKeyData: existingAccount.publicKeyData,
                        settings: existingAccount.settings,
                        order: existingAccount.order,
                        isSelected: true
                    )
                )
                if requiresFullIdentitySynchronization {
                    try walletNetworkSynchronizer?(
                        synchronizedAccounts,
                        existingAccount.address,
                        lifecycleLease
                    )
                } else {
                    try walletNetworkSelectionSynchronizer?(
                        synchronizedAccounts,
                        existingAccount.address,
                        lifecycleLease
                    )
                }
                let selectedAccount = try Self.resolveSelection(
                    accounts: synchronizedAccounts,
                    legacySelectedAddress: existingAccount.address
                )
                guard let selectedAccount else {
                    throw SelectedWalletSettingsError
                        .missingSelectedAccount
                }
                if let legacySettings = self?.legacySettings {
                    legacySettings.set(
                        value: selectedAccount,
                        for: SettingsKey.selectedAccount.rawValue
                    )
                    guard
                        legacySettings.value(
                            of: AccountItem.self,
                            for: SettingsKey.selectedAccount.rawValue
                        ) == selectedAccount
                    else {
                        throw WalletNetworkMigrationError
                            .snapshotVerificationFailed
                    }
                }
                self?.commitInternalValue(selectedAccount)
                completionResult = .success(selectedAccount)
            } catch {
                if case .some(.success) = saveOperation.result {
                    self?.legacySettings?.setWalletMigrationRecovery(
                        reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
                    )
                }
                completionResult = .failure(error)
            }
            // A completion may immediately sign or start another mutation.
            // Finish all durable state and recovery handling before allowing
            // that caller to acquire a new lease. Borrowed leases stay owned
            // by the removal/import operation that supplied them.
            if suppliedLifecycleLease == nil {
                acquiredLease?.release()
            }
            completionClosure(completionResult)
        }

        if suppliedLifecycleLease == nil {
            lifecycleCoordinator.enqueueOwnedAcquireOperation(
                lifecycleOperation
            )
            operationQueue.addOperations(
                [accountsOperation, saveOperation],
                waitUntilFinished: false
            )
        } else {
            operationQueue.addOperations(
                [lifecycleOperation, accountsOperation, saveOperation],
                waitUntilFinished: false
            )
        }
    }

    func performUpdateName(
        account: AccountItem,
        displayName: String,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    ) {
        performUpdate(
            value: account,
            mutation: .displayName(displayName),
            completionClosure: completionClosure
        )
    }

    func performUpdateAssetSettings(
        account: AccountItem,
        settings: AccountSettings,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    ) {
        performUpdate(
            value: account,
            mutation: .assetSettings(settings),
            completionClosure: completionClosure
        )
    }

    private func performUpdate(
        value: AccountItem,
        mutation: WalletAccountMetadataMutation,
        completionClosure: @escaping (Result<AccountItem, Error>) -> Void
    ) {
        let mapper = ManagedAccountItemMapper()
        let repository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )
        let options = RepositoryFetchOptions(
            includesProperties: true,
            includesSubentities: true
        )
        let lifecycleCoordinator = self.lifecycleCoordinator
        let recoveryGate = self.recoveryGate
        let lifecycleOperation =
            lifecycleCoordinator.makeAcquireOperation()
        let accountsOperation = repository.fetchAllOperation(with: options)
        accountsOperation.addDependency(lifecycleOperation)

        let saveOperation = repository.saveOperation({
            _ = try lifecycleOperation.extractNoCancellableResultData()
            try recoveryGate
                .requireAuthorizedLifecycleContinuation()
            let accounts = try accountsOperation
                .extractNoCancellableResultData()
            guard Set(accounts.map(\.address)).count == accounts.count else {
                throw SelectedWalletSettingsError
                    .duplicateAccountIdentifiers
            }
            guard
                let existing = accounts.first(where: {
                    $0.address == value.address
                }),
                existing.address == value.address,
                existing.cryptoType == value.cryptoType,
                existing.networkType == value.networkType,
                existing.publicKeyData == value.publicKeyData
            else {
                throw WalletNetworkMigrationError.legacyIdentityMismatch(
                    value.address
                )
            }
            let selectedAccounts = accounts.filter(\.isSelected)
            guard selectedAccounts.count == 1 else {
                throw selectedAccounts.isEmpty
                    ? SelectedWalletSettingsError.missingSelectedAccount
                    : SelectedWalletSettingsError.multipleSelectedAccounts
            }
            let updatedUsername: String
            let updatedSettings: AccountSettings
            switch mutation {
            case let .displayName(displayName):
                updatedUsername = displayName
                updatedSettings = existing.settings
            case let .assetSettings(settings):
                updatedUsername = existing.username
                updatedSettings = settings
            }
            return [
                ManagedAccountItem(
                    address: existing.address,
                    cryptoType: existing.cryptoType,
                    networkType: existing.networkType,
                    username: updatedUsername,
                    publicKeyData: existing.publicKeyData,
                    order: existing.order,
                    settings: updatedSettings,
                    isSelected: existing.isSelected
                )
            ]
        }, { [] })
        saveOperation.addDependency(accountsOperation)

        let walletNetworkMetadataSynchronizer =
            walletNetworkMetadataSynchronizer
        saveOperation.completionBlock = { [weak self] in
            var acquiredLease: WalletLifecycleLease?
            let completionResult: Result<AccountItem, Error>
            do {
                let lifecycleLease = try lifecycleOperation
                    .extractNoCancellableResultData()
                acquiredLease = lifecycleLease
                _ = try saveOperation.extractNoCancellableResultData()
                try recoveryGate
                    .requireAuthorizedLifecycleContinuation()
                let previousAccounts = try accountsOperation
                    .extractNoCancellableResultData()
                let synchronizedAccounts = previousAccounts.map {
                    account -> AccountItem in
                    guard account.address == value.address else {
                        return AccountItem(
                            address: account.address,
                            cryptoType: account.cryptoType,
                            networkType: account.networkType,
                            username: account.username,
                            publicKeyData: account.publicKeyData,
                            settings: account.settings,
                            order: account.order,
                            isSelected: account.isSelected
                        )
                    }
                    let updatedUsername: String
                    let updatedSettings: AccountSettings
                    switch mutation {
                    case let .displayName(displayName):
                        updatedUsername = displayName
                        updatedSettings = account.settings
                    case let .assetSettings(settings):
                        updatedUsername = account.username
                        updatedSettings = settings
                    }
                    return AccountItem(
                        address: account.address,
                        cryptoType: account.cryptoType,
                        networkType: account.networkType,
                        username: updatedUsername,
                        publicKeyData: account.publicKeyData,
                        settings: updatedSettings,
                        order: account.order,
                        isSelected: account.isSelected
                    )
                }
                let legacySelectedAddress = self?.legacySettings?.value(
                    of: AccountItem.self,
                    for: SettingsKey.selectedAccount.rawValue
                )?.identifier
                let selectedAccount = try Self.resolveSelection(
                    accounts: synchronizedAccounts,
                    legacySelectedAddress: legacySelectedAddress
                )
                guard
                    synchronizedAccounts.isEmpty ||
                        selectedAccount != nil
                else {
                    throw SelectedWalletSettingsError
                        .missingSelectedAccount
                }
                if case let .displayName(displayName) = mutation,
                   displayName != previousAccounts.first(where: {
                       $0.address == value.address
                   })?.username {
                    try walletNetworkMetadataSynchronizer?(
                        synchronizedAccounts,
                        value.address,
                        displayName,
                        lifecycleLease
                    )
                }
                let updatedAccount = synchronizedAccounts.first {
                    $0.address == value.address
                }
                guard let updatedAccount else {
                    throw WalletNetworkMigrationError
                        .explicitRemovalTargetMissing(value.address)
                }
                if selectedAccount?.address == value.address {
                    if let legacySettings = self?.legacySettings {
                        legacySettings.set(
                            value: updatedAccount,
                            for: SettingsKey.selectedAccount.rawValue
                        )
                        guard
                            legacySettings.value(
                                of: AccountItem.self,
                                for: SettingsKey.selectedAccount.rawValue
                            ) == updatedAccount
                        else {
                            throw WalletNetworkMigrationError
                                .snapshotVerificationFailed
                        }
                    }
                    self?.commitInternalValue(updatedAccount)
                }
                completionResult = .success(updatedAccount)
            } catch {
                if case .some(.success) = saveOperation.result {
                    self?.legacySettings?.setWalletMigrationRecovery(
                        reason: UserStorageMigrationError.privacySafeRecoveryDescription(for: error)
                    )
                }
                completionResult = .failure(error)
            }
            acquiredLease?.release()
            completionClosure(completionResult)
        }

        lifecycleCoordinator.enqueueOwnedAcquireOperation(
            lifecycleOperation
        )
        operationQueue.addOperations(
            [accountsOperation, saveOperation],
            waitUntilFinished: false
        )
    }
}

extension SelectedWalletSettings {
    var currentAccount: AccountItem? {
        return value
    }
}
