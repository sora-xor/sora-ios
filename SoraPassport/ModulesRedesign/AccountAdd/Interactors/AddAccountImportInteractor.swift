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
import IrohaCrypto
import SSFUtils
import RobinHood
import SoraKeystore
import SSFCloudStorage
//
final class AddAccountImportInteractor: BaseAccountImportInteractor {
    private(set) var settings: SelectedWalletSettingsProtocol
    let eventCenter: EventCenterProtocol
    private(set) var recoveryAccount: AccountItem?
    private let retainedRecoverySettings: SettingsManagerProtocol
    private let retainedRecoveryKeystore: KeystoreProtocol

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         settings: SelectedWalletSettingsProtocol,
         keystoreImportService: KeystoreImportServiceProtocol,
         eventCenter: EventCenterProtocol,
         cloudStorage: CloudStorageServiceProtocol? = nil,
         recoveryAccount: AccountItem? = nil,
         retainedRecoverySettings: SettingsManagerProtocol = SettingsManager.shared,
         retainedRecoveryKeystore: KeystoreProtocol = Keychain()) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.recoveryAccount = recoveryAccount
        self.retainedRecoverySettings = retainedRecoverySettings
        self.retainedRecoveryKeystore = retainedRecoveryKeystore

        let effectiveAccountOperationFactory: AccountOperationFactoryProtocol
        if recoveryAccount != nil {
            effectiveAccountOperationFactory = Self.makeRetainedRecoveryCandidateFactory()
        } else {
            effectiveAccountOperationFactory = accountOperationFactory
        }

        super.init(accountOperationFactory: effectiveAccountOperationFactory,
                   accountRepository: accountRepository,
                   operationManager: operationManager,
                   keystoreImportService: keystoreImportService,
                   supportedNetworks: Chain.allCases,
                   defaultNetwork: Chain.sora,
                   cloudStorage: cloudStorage,
                   exactMobileBackupOnly: recoveryAccount != nil)
    }

    /// Manual recovery derives and validates secrets in a private capability
    /// context. It does not grant access to the installed wallet; the only real
    /// write is the exact, create-only commit after identity verification.
    static func makeRetainedRecoveryCandidateFactory() -> AccountOperationFactory {
        AccountOperationFactory(
            keystore: InMemoryKeychain(),
            recoveryGate: WalletRecoveryCapabilityGate(
                settings: InMemorySettingsManager(),
                unresolvedMigrationJournal: { false },
                unresolvedWalletCommitJournal: { false }
            )
        )
    }

    override func importAccountUsingOperation(
        _ importOperation: BaseOperation<PreparedAccount>,
        completion: ((Result<AccountItem, Swift.Error>?) -> Void)?
    ) {
        if recoveryAccount != nil {
            importRetainedAccountUsingOperation(
                importOperation,
                completion: completion
            )
            return
        }

        let lifecycleCoordinator = WalletLifecycleCoordinator.shared
        let lifecycleOperation =
            lifecycleCoordinator.makeAcquireOperation()
        importOperation.addDependency(lifecycleOperation)
        let selectionEventCenter = eventCenter
        importOperation.completionBlock = { [weak self] in
            let leaseResult = Result {
                try lifecycleOperation.extractNoCancellableResultData()
            }
            let preparedResult = Result {
                try importOperation.extractNoCancellableResultData()
            }
            guard let self else {
                try? preparedResult.get().discard()
                try? leaseResult.get().release()
                return
            }
            do {
                let lifecycleLease = try leaseResult.get()
                let prepared = try preparedResult.get()
                self.settings.performInsertAndSelect(
                    prepared: prepared,
                    persistSecrets: {
                        try self.accountOperationFactory
                            .persistPreparedAccount(prepared)
                    },
                    lifecycleLease: lifecycleLease
                ) { [weak self] result in
                    self?.finishImport(
                        result,
                        lifecycleLease: lifecycleLease,
                        eventCenter: selectionEventCenter,
                        completion: completion
                    )
                }
            } catch {
                try? preparedResult.get().discard()
                try? leaseResult.get().release()
                DispatchQueue.main.async { [weak self] in
                    self?.presenter?
                        .didReceiveAccountImport(error: error)
                    completion?(.failure(error))
                }
            }
        }

        lifecycleCoordinator.enqueueOwnedAcquireOperation(
            lifecycleOperation
        )
        operationManager.enqueue(
            operations: [importOperation],
            in: .sync
        )
    }
    
    override func validateAccountUsingOperation(
        _ importOperation: BaseOperation<PreparedAccount>,
        completion: ((Result<AccountItem?, Error>?) -> Void)?
    ) {
        if recoveryAccount != nil {
            validateRetainedAccountUsingOperation(
                importOperation,
                completion: completion
            )
            return
        }

        let lifecycleCoordinator = WalletLifecycleCoordinator.shared
        let lifecycleOperation =
            lifecycleCoordinator.makeAcquireOperation()
        importOperation.addDependency(lifecycleOperation)
        importOperation.completionBlock = { [weak self] in
            do {
                let lifecycleLease = try lifecycleOperation
                    .extractNoCancellableResultData()
                let prepared = try importOperation
                    .extractNoCancellableResultData()
                guard let self else {
                    prepared.discard()
                    lifecycleLease.release()
                    return
                }
                let checkOperation = self.accountRepository.fetchOperation(
                    by: prepared.account.address,
                    options: RepositoryFetchOptions()
                )
                checkOperation.completionBlock = {
                    defer {
                        prepared.discard()
                        lifecycleLease.release()
                    }
                    let result: Result<AccountItem?, Error>
                    do {
                        let existingAccount = try checkOperation
                            .extractNoCancellableResultData()
                        if existingAccount != nil {
                            throw AccountCreateError.duplicated
                        }
                        result = .success(prepared.account)
                    } catch {
                        result = .failure(error)
                    }
                    DispatchQueue.main.async {
                        completion?(result)
                    }
                }
                self.operationManager.enqueue(
                    operations: [checkOperation],
                    in: .sync
                )
            } catch {
                (try? importOperation
                    .extractNoCancellableResultData())?.discard()
                (try? lifecycleOperation
                    .extractNoCancellableResultData())?.release()
                DispatchQueue.main.async { [weak self] in
                    self?.presenter?
                        .didReceiveAccountImport(error: error)
                    completion?(.failure(error))
                }
            }
        }
        
        lifecycleCoordinator.enqueueOwnedAcquireOperation(
            lifecycleOperation
        )
        operationManager.enqueue(
            operations: [importOperation],
            in: .sync
        )
    }

    private func importRetainedAccountUsingOperation(
        _ importOperation: BaseOperation<PreparedAccount>,
        completion: ((Result<AccountItem, Swift.Error>?) -> Void)?
    ) {
        importOperation.completionBlock = { [weak self] in
            let preparedResult = Result {
                try importOperation.extractNoCancellableResultData()
            }
            guard let self else {
                try? preparedResult.get().discard()
                return
            }

            do {
                let prepared = try preparedResult.get()
                guard
                    let recoveryAccount = self.recoveryAccount,
                    SelectedWalletSettings.hasExactStoredRetainedRecoveryIdentity(
                        settings: self.retainedRecoverySettings,
                        account: recoveryAccount
                    )
                else {
                    prepared.discard()
                    throw AccountCreateError.invalidSeed
                }

                let checkOperation = self.accountRepository.fetchOperation(
                    by: prepared.account.address,
                    options: RepositoryFetchOptions()
                )
                checkOperation.completionBlock = { [weak self] in
                    guard let self else {
                        prepared.discard()
                        return
                    }
                    do {
                        guard
                            let existingAccount = try checkOperation
                                .extractNoCancellableResultData(),
                            Self.isRecoveryIdentityMatch(
                                prepared.account,
                                expected: recoveryAccount,
                                existing: existingAccount
                            )
                        else {
                            prepared.discard()
                            throw AccountCreateError.invalidSeed
                        }

                        let candidate = try RetainedWalletBackupCandidate
                            .consuming(prepared)
                        guard try RetainedWalletVerifiedCandidateCommitter
                            .persistVerifiedCandidate(
                                candidate,
                                retainedAccount: recoveryAccount,
                                settings: self.retainedRecoverySettings,
                                keystore: self.retainedRecoveryKeystore
                            )
                        else {
                            throw AccountCreateError.invalidSeed
                        }

                        // The existing database row is deliberately not saved,
                        // renamed, reselected, or reordered during recovery.
                        self.finishRetainedRecoveryImport(
                            .success(existingAccount),
                            completion: completion
                        )
                    } catch {
                        prepared.discard()
                        self.finishRetainedRecoveryImport(
                            .failure(error),
                            completion: completion
                        )
                    }
                }
                self.operationManager.enqueue(
                    operations: [checkOperation],
                    in: .sync
                )
            } catch {
                try? preparedResult.get().discard()
                self.finishRetainedRecoveryImport(
                    .failure(error),
                    completion: completion
                )
            }
        }

        operationManager.enqueue(
            operations: [importOperation],
            in: .sync
        )
    }

    private func validateRetainedAccountUsingOperation(
        _ importOperation: BaseOperation<PreparedAccount>,
        completion: ((Result<AccountItem?, Error>?) -> Void)?
    ) {
        importOperation.completionBlock = { [weak self] in
            do {
                let prepared = try importOperation.extractNoCancellableResultData()
                guard let self, let recoveryAccount = self.recoveryAccount else {
                    prepared.discard()
                    return
                }
                let checkOperation = self.accountRepository.fetchOperation(
                    by: prepared.account.address,
                    options: RepositoryFetchOptions()
                )
                checkOperation.completionBlock = {
                    defer { prepared.discard() }
                    let result: Result<AccountItem?, Error>
                    do {
                        guard
                            SelectedWalletSettings.hasExactStoredRetainedRecoveryIdentity(
                                settings: self.retainedRecoverySettings,
                                account: recoveryAccount
                            ),
                            let existingAccount = try checkOperation
                                .extractNoCancellableResultData(),
                            Self.isRecoveryIdentityMatch(
                                prepared.account,
                                expected: recoveryAccount,
                                existing: existingAccount
                            )
                        else {
                            throw AccountCreateError.invalidSeed
                        }
                        result = .success(prepared.account)
                    } catch {
                        result = .failure(error)
                    }
                    DispatchQueue.main.async {
                        completion?(result)
                    }
                }
                self.operationManager.enqueue(
                    operations: [checkOperation],
                    in: .sync
                )
            } catch {
                (try? importOperation.extractNoCancellableResultData())?.discard()
                DispatchQueue.main.async { [weak self] in
                    self?.presenter?.didReceiveAccountImport(error: error)
                    completion?(.failure(error))
                }
            }
        }

        operationManager.enqueue(
            operations: [importOperation],
            in: .sync
        )
    }

    private func finishRetainedRecoveryImport(
        _ result: Result<AccountItem, Error>,
        completion: ((Result<AccountItem, Swift.Error>?) -> Void)?
    ) {
        DispatchQueue.main.async { [weak self] in
            switch result {
            case let .success(accountItem):
                self?.presenter?.didCompleteAccountImport()
                completion?(.success(accountItem))
            case let .failure(error):
                self?.presenter?.didReceiveAccountImport(error: error)
                completion?(.failure(error))
            }
        }
    }

    private func finishImport(
        _ result: Result<AccountItem, Error>,
        lifecycleLease: WalletLifecycleLease,
        eventCenter: EventCenterProtocol? = nil,
        completion: ((Result<AccountItem, Swift.Error>?) -> Void)?
    ) {
        lifecycleLease.release()
        DispatchQueue.main.async { [weak self] in
            switch result {
            case let .success(accountItem):
                (eventCenter ?? self?.eventCenter)?.notify(
                    with: SelectedAccountChanged(),
                    completionOnMain: { [weak self] in
                        self?.presenter?.didCompleteAccountImport()
                        completion?(.success(accountItem))
                    }
                )
            case let .failure(error):
                self?.presenter?.didReceiveAccountImport(error: error)
                completion?(.failure(error))
            }
        }
    }

    private static func isRecoveryIdentityMatch(
        _ candidate: AccountItem,
        expected: AccountItem,
        existing: AccountItem
    ) -> Bool {
        candidate.address == expected.address &&
            candidate.publicKeyData == expected.publicKeyData &&
            candidate.networkType == expected.networkType &&
            candidate.cryptoType == expected.cryptoType &&
            existing.address == expected.address &&
            existing.publicKeyData == expected.publicKeyData &&
            existing.networkType == expected.networkType &&
            existing.cryptoType == expected.cryptoType
    }

    static func isValidRecoveryReplacement(
        _ candidate: AccountItem,
        expected: AccountItem,
        existing: AccountItem,
        keystore: KeystoreProtocol
    ) -> Bool {
        guard isRecoveryIdentityMatch(
            candidate,
            expected: expected,
            existing: existing
        ) else {
            return false
        }

        if candidate.cryptoType == .sr25519 {
            guard
                let secret = try? keystore.fetchSecretKeyForAddress(
                    candidate.address
                ),
                SNSafeKeypairValidator.isValidSr25519SecretKey(
                    secret,
                    publicKey: candidate.publicKeyData
                )
            else {
                return false
            }
        }

        return SelectedWalletSettings.hasVerifiedSigningKey(
            keystore: keystore,
            account: candidate
        )
    }

    static func recoveredAccount(
        existing: AccountItem,
        candidate: AccountItem
    ) -> AccountItem {
        _ = candidate
        return existing
    }
}
