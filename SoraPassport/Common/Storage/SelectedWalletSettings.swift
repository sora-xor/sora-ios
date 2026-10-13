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

// Recovery reads the existing backup directly. Ordinary cloud browsing can
// create a folder and ordinary import can create an account; neither belongs
// in recovery for an already retained identity.
import GoogleAPIClientForREST_Drive
import GoogleAPIClientForRESTCore
import GoogleSignIn
import IrohaCrypto
import SSFCloudStorage
import SSFUtils
import TweetNacl
import UIKit

enum WalletCloudBackupWriteError: Error {
    case invalidBackup, ambiguous, preservationFailed, verificationFailed, busy

    static func userMessage(for error: Error) -> String {
        switch error as? Self {
        case .invalidBackup:
            return "The wallet backup could not be prepared safely. Existing backups were kept."
        case .ambiguous:
            return "More than one existing backup matches this wallet. Existing backups were kept."
        case .preservationFailed:
            return "Google Drive could not preserve the previous backup revision. It was not replaced. Try again later."
        case .verificationFailed:
            return "The new backup could not be verified. Previous backup revisions were kept. Try again."
        case .busy:
            return "A backup is already being saved. Wait for it to finish."
        default:
            return "The backup could not be saved and verified. Existing backups were not deleted. Try again."
        }
    }
}

/// Keeps the library's backup encoder and authentication flow, while replacing
/// its final create request with a verified create or preserved-revision update.
final class WalletBackupPreservingGoogleService: GoogleService {
    private let base: GoogleService
    private let lock = NSLock()
    private var saving = false
    private static let fileFields = "id,name,size,mimeType,trashed,headRevisionId,version"

    init(base: GoogleService = BaseGoogleService(googleService: GTLRDriveService())) {
        self.base = base
    }

    func set(authorizer: GTMFetcherAuthorizationProtocol?) { base.set(authorizer: authorizer) }

    func executeQuery(_ query: GTLRQueryProtocol) async throws -> (ticket: GoogleServiceTicket, file: Any?) {
        if let list = query as? GTLRDriveQuery_FilesList,
           list.spaces == "appDataFolder", list.q == "name = 'backupFolder'" {
            let result = try await boundedList("name = 'backupFolder' and mimeType = 'application/vnd.google-apps.folder' and trashed = false")
            guard result.files.count <= 1 else { throw WalletCloudBackupWriteError.ambiguous }
            for folder in result.files {
                guard folder.name == "backupFolder", folder.mimeType == "application/vnd.google-apps.folder",
                      folder.trashed?.boolValue != true, validID(folder.identifier) else {
                    throw WalletCloudBackupWriteError.invalidBackup
                }
            }
            let files = GTLRDrive_FileList(); files.files = result.files
            return (result.ticket, files)
        }
        guard let create = query as? GTLRDriveQuery_FilesCreate,
              let metadata = create.bodyObject as? GTLRDrive_File else {
            throw WalletCloudBackupWriteError.invalidBackup
        }
        if create.uploadParameters == nil {
            guard metadata.name == "backupFolder", metadata.mimeType == "application/vnd.google-apps.folder",
                  metadata.parents == ["appDataFolder"] else { throw WalletCloudBackupWriteError.invalidBackup }
            let result = try await base.executeQuery(create)
            guard let folder = result.file as? GTLRDrive_File, validID(folder.identifier) else {
                throw WalletCloudBackupWriteError.verificationFailed
            }
            return result
        }
        try beginSaving()
        defer { endSaving() }
        return try await save(create, metadata: metadata)
    }

    private func beginSaving() throws {
        lock.lock(); defer { lock.unlock() }
        guard !saving else { throw WalletCloudBackupWriteError.busy }
        saving = true
    }

    private func endSaving() {
        lock.lock(); defer { lock.unlock() }
        saving = false
    }

    private func validID(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.isEmpty && value.utf8.count <= 1024 &&
            !value.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    private func boundedList(_ filter: String) async throws -> (ticket: GoogleServiceTicket, files: [GTLRDrive_File]) {
        var files: [GTLRDrive_File] = []
        var token: String?
        var tokens = Set<String>()
        for page in 0..<4 {
            try Task.checkCancellation()
            let query = GTLRDriveQuery_FilesList.query()
            query.spaces = "appDataFolder"; query.q = filter
            query.fields = "nextPageToken,incompleteSearch,files(\(Self.fileFields))"
            query.pageSize = 100; query.pageToken = token
            let result = try await base.executeQuery(query)
            guard let list = result.file as? GTLRDrive_FileList,
                  list.incompleteSearch?.boolValue != true, (list.files?.count ?? 0) <= 100 else {
                throw WalletCloudBackupWriteError.invalidBackup
            }
            files.append(contentsOf: list.files ?? [])
            guard files.count <= 1 else { throw WalletCloudBackupWriteError.ambiguous }
            token = list.nextPageToken
            if token == nil || token == "" { return (result.ticket, files) }
            guard page < 3, validID(token), tokens.insert(token!).inserted else {
                throw WalletCloudBackupWriteError.invalidBackup
            }
        }
        throw WalletCloudBackupWriteError.invalidBackup
    }

    private func validateFile(_ file: GTLRDrive_File, name: String, identifier: String? = nil) throws {
        guard validID(file.identifier), identifier == nil || file.identifier == identifier,
              file.name == name, file.trashed?.boolValue != true,
              file.mimeType == "application/json", validID(file.headRevisionId),
              let size = file.size?.int64Value, size > 0,
              size <= Int64(WalletCloudBackupRecoveryService.maximumBackupBytes),
              let version = file.version?.int64Value, version > 0 else {
            throw WalletCloudBackupWriteError.verificationFailed
        }
    }

    private func metadata(_ identifier: String, name: String) async throws -> GTLRDrive_File {
        let query = GTLRDriveQuery_FilesGet.query(withFileId: identifier)
        query.fields = Self.fileFields
        let result = try await base.executeQuery(query)
        guard let file = result.file as? GTLRDrive_File else { throw WalletCloudBackupWriteError.verificationFailed }
        try validateFile(file, name: name, identifier: identifier)
        return file
    }

    private func media(_ query: GTLRQueryProtocol) async throws -> Data {
        let result = try await base.executeQuery(query)
        guard let data = (result.file as? GTLRDataObject)?.data, !data.isEmpty,
              data.count <= WalletCloudBackupRecoveryService.maximumBackupBytes else {
            throw WalletCloudBackupWriteError.verificationFailed
        }
        return data
    }

    private func verifyPinnedRevision(file: String, revision: String) async throws {
        let query = GTLRDriveQuery_RevisionsGet.query(withFileId: file, revisionId: revision)
        query.fields = "id,keepForever"
        let result = try await base.executeQuery(query)
        guard let retained = result.file as? GTLRDrive_Revision,
              retained.identifier == revision, retained.keepForever?.boolValue == true else {
            throw WalletCloudBackupWriteError.preservationFailed
        }
    }

    private func save(_ create: GTLRDriveQuery_FilesCreate, metadata submitted: GTLRDrive_File)
        async throws -> (ticket: GoogleServiceTicket, file: Any?) {
        guard let payload = create.uploadParameters?.data, !payload.isEmpty,
              payload.count <= WalletCloudBackupRecoveryService.maximumBackupBytes,
              let envelope = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let address = envelope["address"] as? String,
              (32...128).contains(address.count),
              address.allSatisfy({ "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".contains($0) }),
              submitted.name == "\(address).json",
              let parents = submitted.parents, parents.count == 1, validID(parents[0]) else {
            throw WalletCloudBackupWriteError.invalidBackup
        }
        let name = "\(address).json"
        let matches = try await boundedList("name = '\(name)' and trashed = false")
        let result: (ticket: GoogleServiceTicket, file: Any?)
        if let old = matches.files.first {
            try validateFile(old, name: name)
            let identifier = old.identifier!
            let original = try await metadata(identifier, name: name)
            guard original.headRevisionId == old.headRevisionId, original.version == old.version else {
                throw WalletCloudBackupWriteError.preservationFailed
            }
            let originalData = try await media(GTLRDriveQuery_FilesGet.queryForMedia(withFileId: identifier))
            guard Int64(originalData.count) == original.size?.int64Value else {
                throw WalletCloudBackupWriteError.preservationFailed
            }
            let revision = original.headRevisionId!
            do {
                let retained = GTLRDrive_Revision(); retained.keepForever = true
                let pin = GTLRDriveQuery_RevisionsUpdate.query(withObject: retained, fileId: identifier, revisionId: revision)
                pin.fields = "id,keepForever"
                _ = try await base.executeQuery(pin)
                try await verifyPinnedRevision(file: identifier, revision: revision)
            } catch { throw WalletCloudBackupWriteError.preservationFailed }
            // Pinning itself can change the file version. Compare only subsequent
            // metadata snapshots, while keeping the original head and bytes fixed.
            let afterPin = try await metadata(identifier, name: name)
            guard afterPin.headRevisionId == revision else { throw WalletCloudBackupWriteError.preservationFailed }
            let preservedData = try await media(GTLRDriveQuery_RevisionsGet.queryForMedia(withFileId: identifier, revisionId: revision))
            guard preservedData == originalData else { throw WalletCloudBackupWriteError.preservationFailed }
            let beforeWrite = try await metadata(identifier, name: name)
            guard beforeWrite.headRevisionId == revision, beforeWrite.version == afterPin.version else {
                throw WalletCloudBackupWriteError.preservationFailed
            }
            let updateMetadata = GTLRDrive_File()
            updateMetadata.descriptionProperty = submitted.descriptionProperty
            let update = GTLRDriveQuery_FilesUpdate.query(withObject: updateMetadata,
                fileId: identifier, uploadParameters: create.uploadParameters)
            update.keepRevisionForever = true
            update.fields = Self.fileFields
            result = try await base.executeQuery(update)
        } else {
            create.keepRevisionForever = true
            create.fields = Self.fileFields
            result = try await base.executeQuery(create)
        }
        guard let saved = result.file as? GTLRDrive_File else { throw WalletCloudBackupWriteError.verificationFailed }
        try validateFile(saved, name: name, identifier: matches.files.first?.identifier)
        guard saved.size?.int64Value == Int64(payload.count) else { throw WalletCloudBackupWriteError.verificationFailed }
        do { try await verifyPinnedRevision(file: saved.identifier!, revision: saved.headRevisionId!) }
        catch { throw WalletCloudBackupWriteError.verificationFailed }
        let uploaded = try await media(GTLRDriveQuery_FilesGet.queryForMedia(withFileId: saved.identifier!))
        guard uploaded == payload else { throw WalletCloudBackupWriteError.verificationFailed }
        let final = try await metadata(saved.identifier!, name: name)
        guard final.headRevisionId == saved.headRevisionId, final.size == saved.size else {
            throw WalletCloudBackupWriteError.verificationFailed
        }
        return result
    }
}

enum WalletCloudBackupRecoveryError: Error {
    case notAuthorized, authorizationCanceled, notFound, ambiguous, invalidBackup, incorrectPassword
    case identityMismatch, unsupportedBackup, unavailable

    static func authorizationError(for error: Error) -> Self {
        let system = error as NSError
        // GIDSignIn's public kGIDSignInErrorCodeCanceled is -5.
        if error is CancellationError || (system.domain == kGIDSignInErrorDomain && system.code == -5) {
            return .authorizationCanceled
        }
        return .notAuthorized
    }

    static func title(for error: Error) -> String {
        switch error as? Self {
        case .notFound: return "Backup not found"
        case .authorizationCanceled: return "Google sign-in canceled"
        case .notAuthorized: return "Google sign-in required"
        default: return "Wallet keys not restored"
        }
    }

    static func userMessage(for error: Error) -> String {
        if let system = error as? KeystoreSystemError {
            return "The iPhone could not access protected wallet storage (Keychain status \(system.status)). Unlock it and try again."
        }
        if case WalletNetworkMigrationError.legacyIdentityMismatch = error {
            return "This backup does not match the existing wallet. No wallet keys were changed."
        }
        if error is UserStorageMigrationError || error is KeystoreError {
            return "The existing wallet storage could not be updated safely. Existing wallet data was preserved."
        }
        guard let error = error as? Self else {
            return "The backup could not be verified. Existing wallet data was preserved."
        }
        switch error {
        case .notAuthorized: return "Sign in to the Google account that holds your wallet backup."
        case .authorizationCanceled: return "Google sign-in was canceled. No wallet keys were changed. Tap Restore from Google Drive backup to choose an account again."
        case .notFound: return "No backup for this existing wallet was found in the selected Google account. Tap Restore from Google Drive backup again to choose another Google account."
        case .ambiguous: return "More than one backup matches this wallet. No wallet keys were changed."
        case .invalidBackup: return "The backup file is incomplete or unsupported. No wallet keys were changed."
        case .incorrectPassword: return "The backup could not be decrypted with this password. Try the original backup password."
        case .identityMismatch: return "This backup does not match the existing wallet. No wallet keys were changed."
        case .unsupportedBackup: return "This backup has no supported SORA signing credentials. No wallet keys were changed."
        case .unavailable: return "Google Drive could not be read. Try again when the connection is available."
        }
    }
}

final class WalletCloudBackupRecoveryService {
    static let maximumBackupBytes = 1_048_576
    private let drive: GoogleService
    private let authorize: () async throws -> Bool

    init(viewController: UIViewController) {
        let recoveryDrive = BaseGoogleService(googleService: GTLRDriveService())
        drive = recoveryDrive
        authorize = {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                Task { @MainActor in
                    // Recovery must let the user choose the backup's Google account
                    // even when ordinary cloud browsing already has a saved session.
                    GIDSignIn.sharedInstance.signIn(withPresenting: viewController, hint: nil,
                        additionalScopes: [kGTLRAuthScopeDriveAppdata]) { result, error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }
                        guard let user = result?.user,
                              user.grantedScopes?.contains(kGTLRAuthScopeDriveAppdata) == true else {
                            continuation.resume(returning: false)
                            return
                        }
                        recoveryDrive.set(authorizer: user.fetcherAuthorizer)
                        continuation.resume(returning: true)
                    }
                }
            }
        }
    }

    init(drive: GoogleService, authorize: @escaping () async throws -> Bool) {
        self.drive = drive
        self.authorize = authorize
    }

    func readBackup(for address: String) async throws -> Data {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        guard (32...128).contains(address.count), address.allSatisfy({ alphabet.contains($0) }) else {
            throw WalletCloudBackupRecoveryError.identityMismatch
        }
        do {
            try Task.checkCancellation()
            guard try await authorize() else { throw WalletCloudBackupRecoveryError.notAuthorized }
        } catch let error as WalletCloudBackupRecoveryError { throw error }
        catch { throw WalletCloudBackupRecoveryError.authorizationError(for: error) }
        do {
            var token: String?
            var seenTokens = Set<String>()
            var matches: [GTLRDrive_File] = []
            for page in 0..<4 {
                try Task.checkCancellation()
                let query = GTLRDriveQuery_FilesList.query()
                query.spaces = "appDataFolder"
                query.q = "name = '\(address).json' and trashed = false"
                query.fields = "nextPageToken,incompleteSearch,files(id,name,size,trashed,mimeType)"
                query.pageSize = 100
                query.pageToken = token
                let result = try await drive.executeQuery(query)
                guard let list = result.file as? GTLRDrive_FileList,
                      list.incompleteSearch?.boolValue != true,
                      (list.files?.count ?? 0) <= 100 else {
                    throw WalletCloudBackupRecoveryError.invalidBackup
                }
                for file in list.files ?? [] {
                    guard file.name == "\(address).json", file.trashed?.boolValue != true,
                          file.mimeType != "application/vnd.google-apps.folder",
                          let identifier = file.identifier, !identifier.isEmpty,
                          let size = file.size?.int64Value, size > 0,
                          size <= Int64(Self.maximumBackupBytes) else {
                        throw WalletCloudBackupRecoveryError.invalidBackup
                    }
                    matches.append(file)
                    guard matches.count <= 1 else { throw WalletCloudBackupRecoveryError.ambiguous }
                }
                token = list.nextPageToken
                if token == nil || token == "" { break }
                guard page < 3, seenTokens.insert(token!).inserted else {
                    throw WalletCloudBackupRecoveryError.invalidBackup
                }
            }
            guard let file = matches.first, let identifier = file.identifier else {
                throw WalletCloudBackupRecoveryError.notFound
            }
            try Task.checkCancellation()
            let result = try await drive.executeQuery(GTLRDriveQuery_FilesGet.queryForMedia(withFileId: identifier))
            guard let data = (result.file as? GTLRDataObject)?.data,
                  !data.isEmpty, data.count <= Self.maximumBackupBytes,
                  Int64(data.count) == file.size?.int64Value else {
                throw WalletCloudBackupRecoveryError.invalidBackup
            }
            return data
        } catch let error as WalletCloudBackupRecoveryError { throw error }
        catch { throw WalletCloudBackupRecoveryError.unavailable }
    }

    private struct Backup: Decodable {
        let address: String
        let keyVerifier: String?
        let encryptedMnemonicPhrase: String?
        let encryptedSubstrateDerivationPath: String?
        let cryptoType: String?
        let encryptedSeed: OpenBackupAccount.Seed?
        let json: OpenBackupAccount.Json?
    }

    static func restore(data: Data, password: String, account: AccountItem,
                        migrator: UserStorageMigrator, baseURL: URL? = nil,
                        lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
                        checkpoint: () throws -> Void = {}) throws {
        guard !data.isEmpty, data.count <= maximumBackupBytes,
              let backup = try? JSONDecoder().decode(Backup.self, from: data) else {
            throw WalletCloudBackupRecoveryError.invalidBackup
        }
        guard backup.address == account.address else { throw WalletCloudBackupRecoveryError.identityMismatch }
        if let crypto = backup.cryptoType, !crypto.isEmpty {
            guard crypto.lowercased() == account.cryptoType.typeString.lowercased() ||
                    crypto == String(account.cryptoType.rawValue) else {
                throw WalletCloudBackupRecoveryError.identityMismatch
            }
        }
        let encryption = EncryptionService()
        func decrypt(_ value: String?) throws -> String? {
            guard let value, !value.isEmpty else { return nil }
            guard let bytes = try? Data(hexStringSSF: value) else {
                throw WalletCloudBackupRecoveryError.invalidBackup
            }
            _ = try checkedScrypt(bytes)
            do { return try encryption.getDecrypted(from: value, password: password) }
            catch { throw WalletCloudBackupRecoveryError.incorrectPassword }
        }
        guard let verifier = try decrypt(backup.keyVerifier), verifier == account.address else {
            throw WalletCloudBackupRecoveryError.incorrectPassword
        }
        var phrase = try decrypt(backup.encryptedMnemonicPhrase)
        defer { phrase = nil }
        let path = try decrypt(backup.encryptedSubstrateDerivationPath) ?? ""
        var entropy: Data?
        var seed: Data?
        var secret: Data?
        defer {
            if let count = entropy?.count { entropy?.resetBytes(in: 0..<count) }
            if let count = seed?.count { seed?.resetBytes(in: 0..<count) }
            if let count = secret?.count { secret?.resetBytes(in: 0..<count) }
        }
        if let phrase, !phrase.isEmpty {
            guard let mnemonic = try? IRMnemonicCreator(language: .english)
                .mnemonic(fromList: phrase.split(whereSeparator: \.isWhitespace).joined(separator: " ")),
                WalletMnemonicWordPolicy.retainedSoraWordCounts.contains(mnemonic.allWords().count) else {
                throw WalletCloudBackupRecoveryError.invalidBackup
            }
            entropy = mnemonic.entropy()
        }
        if let seedString = try decrypt(backup.encryptedSeed?.substrateSeed), !seedString.isEmpty {
            guard let decoded = try? Data(hexStringSSF: seedString), [32, 64].contains(decoded.count) else {
                throw WalletCloudBackupRecoveryError.invalidBackup
            }
            seed = decoded
        }
        if let json = backup.json?.substrateJson, !json.isEmpty {
            secret = try extractJSONSecret(json, password: password, account: account)
        }
        guard entropy != nil || seed != nil || secret != nil else {
            throw WalletCloudBackupRecoveryError.unsupportedBackup
        }
        try migrator.restoreMissingBackupMaterial(address: account.address, expectedAccount: account,
            entropy: entropy, rawSeed: seed, secret: secret, derivationPath: path,
            baseURL: baseURL, lifecycleCoordinator: lifecycleCoordinator, checkpoint: checkpoint)
    }

    private static func checkedScrypt(_ data: Data) throws -> ScryptParameters {
        // The retained writer uses N=32768,r=8,p=1. Bound work before invoking
        // the existing native decoder and ensure nonce/MAC slices exist.
        guard data.count >= ScryptParameters.encodedLength + 24 + 16,
              data.count <= maximumBackupBytes else { throw WalletCloudBackupRecoveryError.invalidBackup }
        let params = try ScryptParameters(data: data)
        let n = UInt64(params.scryptN), r = UInt64(params.scryptR), p = UInt64(params.scryptP)
        guard n >= 2, n.nonzeroBitCount == 1, n <= 262_144,
              r > 0, r <= 32, p > 0, p <= 16,
              n * r <= 2_097_152, n * r * p <= 4_194_304 else {
            throw WalletCloudBackupRecoveryError.invalidBackup
        }
        return params
    }

    private static func extractJSONSecret(_ json: String, password: String, account: AccountItem) throws -> Data {
        guard let bytes = json.data(using: .utf8), bytes.count <= maximumBackupBytes,
              let definition = try? JSONDecoder().decode(KeystoreDefinition.self, from: bytes),
              let info = try? KeystoreInfoFactory().createInfo(from: definition),
              info.cryptoType.stringValue == account.cryptoType.typeString.lowercased(),
              definition.address == nil || definition.address == account.address,
              definition.encoding.content == ["pkcs8", account.cryptoType.typeString.lowercased()],
              let encoded = Data(base64Encoded: definition.encoded) else {
            throw WalletCloudBackupRecoveryError.invalidBackup
        }
        var pkcs: Data
        if definition.encoding.type.isEmpty {
            pkcs = encoded
        } else {
            guard definition.encoding.type == ["scrypt", "xsalsa20-poly1305"] else {
                throw WalletCloudBackupRecoveryError.unsupportedBackup
            }
            let params = try checkedScrypt(encoded)
            var key = try IRScryptKeyDeriviation().deriveKey(from: Data(password.utf8),
                salt: params.salt, scryptN: UInt(params.scryptN), scryptP: UInt(params.scryptP),
                scryptR: UInt(params.scryptR), length: 32)
            defer { key.resetBytes(in: key.startIndex..<key.endIndex) }
            let nonceEnd = ScryptParameters.encodedLength + 24
            do {
                pkcs = try NaclSecretBox.open(box: Data(encoded[nonceEnd...]),
                    nonce: Data(encoded[ScryptParameters.encodedLength..<nonceEnd]), key: key)
            } catch { throw WalletCloudBackupRecoveryError.incorrectPassword }
        }
        defer { pkcs.resetBytes(in: pkcs.startIndex..<pkcs.endIndex) }
        let header = SSFUtils.KeystoreConstants.pkcs8Header
        let divider = SSFUtils.KeystoreConstants.pkcs8Divider
        let privateLength = pkcs.count - header.count - divider.count - account.publicKeyData.count
        let admittedLengths = account.cryptoType == .ed25519 ? [32, 64] : [account.cryptoType == .sr25519 ? 64 : 32]
        let publicStart = header.count + privateLength + divider.count
        guard admittedLengths.contains(privateLength), pkcs.count == publicStart + account.publicKeyData.count,
              pkcs.starts(with: header),
              pkcs.subdata(in: header.count + privateLength..<publicStart) == divider,
              pkcs.range(of: divider)?.lowerBound == header.count + privateLength,
              pkcs.suffix(account.publicKeyData.count) == account.publicKeyData else {
            throw WalletCloudBackupRecoveryError.identityMismatch
        }
        if account.cryptoType == .sr25519 {
            var scalar = Array(pkcs[header.count..<header.count + 32])
            guard scalar[0] & 7 == 0 else { throw WalletCloudBackupRecoveryError.invalidBackup }
            for i in 0..<31 { scalar[i] = (scalar[i] >> 3) | (scalar[i + 1] << 5) }
            scalar[31] >>= 3
            guard isCanonicalScalar(scalar) else { throw WalletCloudBackupRecoveryError.invalidBackup }
        }
        let plain = KeystoreDefinition(address: definition.address, encoded: pkcs.base64EncodedString(),
            encoding: KeystoreEncoding(content: definition.encoding.content, type: [],
                version: definition.encoding.version), meta: definition.meta)
        let extracted = try KeystoreExtractor().extractFromDefinition(plain, password: nil)
        guard extracted.publicKeyData == account.publicKeyData, extracted.cryptoType.stringValue == account.cryptoType.typeString.lowercased() else {
            throw WalletCloudBackupRecoveryError.identityMismatch
        }
        try validateSecretEncoding(extracted.secretKeyData, cryptoType: account.cryptoType, publicKey: account.publicKeyData)
        return extracted.secretKeyData
    }

    static func validateSecretEncoding(_ secret: Data, cryptoType: CryptoType, publicKey: Data) throws {
        // Released Ed25519 JSON imports may retain seed + public key. Keep that
        // representation intact, but never discard or ignore a conflicting suffix.
        if cryptoType == .ed25519, secret.count == 64 {
            guard publicKey.count == 32, secret.suffix(32) == publicKey else {
                throw WalletCloudBackupRecoveryError.identityMismatch
            }
            return
        }
        guard secret.count == (cryptoType == .sr25519 ? 64 : 32),
              cryptoType != .sr25519 || isCanonicalScalar(Array(secret.prefix(32))) else {
            throw WalletCloudBackupRecoveryError.invalidBackup
        }
    }

    private static func isCanonicalScalar(_ bytes: [UInt8]) -> Bool {
        // Little-endian subgroup order; this is an input-format check before
        // native signing, not key derivation or a replacement crypto primitive.
        let order: [UInt8] = [0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58,
            0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x10]
        guard bytes.count == 32 else { return false }
        for i in (0..<32).reversed() {
            if bytes[i] != order[i] { return bytes[i] < order[i] }
        }
        return false
    }
}
