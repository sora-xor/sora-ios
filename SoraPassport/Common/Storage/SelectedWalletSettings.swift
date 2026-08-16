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
        let hasSigningMaterial = try keystore.checkSecretKeyForAddress(account.address) ||
            keystore.checkEntropyForAddress(account.address) ||
            keystore.checkSeedForAddress(account.address)
        guard !hasSigningMaterial else {
            // Retained key material must be cryptographically matched before it can be used.
            // This rollback build only restores public metadata for a read-only preview.
            return nil
        }

        return RetainedAccountRepairPlan(account: account)
    }

    static func requiresRecoveryReadOnlyMode(
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol,
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

        guard derivedAddress == account.address else {
            return false
        }

        guard hasVerifiedSigningKey(keystore: keystore, account: account) else {
            return true
        }

        settings.removeValue(for: RetainedAccountRepairKey.recoveryRequired)
        settings.removeValue(for: "walletMigrationRecoveryReason")
        settings.removeValue(for: RetainedAccountRepairKey.recoveryAccount)
        return false
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
            let signature = try SigningWrapper(keystore: keystore, account: account).sign(challenge)

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
