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
    private let recoveryAccount: AccountItem?

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         settings: SelectedWalletSettingsProtocol,
         keystoreImportService: KeystoreImportServiceProtocol,
         eventCenter: EventCenterProtocol,
         cloudStorage: CloudStorageServiceProtocol? = nil,
         recoveryAccount: AccountItem? = nil) {
        self.settings = settings
        self.eventCenter = eventCenter
        self.recoveryAccount = recoveryAccount

        super.init(accountOperationFactory: accountOperationFactory,
                   accountRepository: accountRepository,
                   operationManager: operationManager,
                   keystoreImportService: keystoreImportService,
                   supportedNetworks: Chain.allCases,
                   defaultNetwork: Chain.sora,
                   cloudStorage: cloudStorage)
    }

    private func importAccountItem(_ item: AccountItem, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?) {
        let checkOperation = accountRepository.fetchOperation(by: item.address,
                                                              options: RepositoryFetchOptions())

        let persistentOperation = accountRepository.saveOperation({
            let existingAccount = try checkOperation.extractResultData(
                throwing: BaseOperationError.parentOperationCancelled
            )

            if let recoveryAccount = self.recoveryAccount {
                guard
                    let existingAccount,
                    Self.isValidRecoveryReplacement(
                        item,
                        expected: recoveryAccount,
                        existing: existingAccount,
                        keystore: Keychain()
                    )
                else {
                    throw AccountCreateError.invalidSeed
                }
            } else if existingAccount != nil {
                throw AccountCreateError.duplicated
            }

            return [item]
        }, { [] })

        persistentOperation.addDependency(checkOperation)

        let connectionOperation: BaseOperation<AccountItem> = ClosureOperation {
            if case .failure(let error) = persistentOperation.result {
                throw error
            }

            return item
        }

        connectionOperation.addDependency(persistentOperation)

        connectionOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch connectionOperation.result {
                case .success(let accountItem):
                    self?.settings.save(value: accountItem)
                    self?.eventCenter.notify(with: SelectedAccountChanged())
                    self?.presenter?.didCompleteAccountImport()
                case .failure(let error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
                
                completion?(connectionOperation.result)
            }
        }

        operationManager.enqueue(operations: [checkOperation, persistentOperation, connectionOperation],
                                 in: .sync)
    }
    
    private func validateAccountItem(_ item: AccountItem, completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?) {
        let checkOperation = accountRepository.fetchOperation(by: item.address,
                                                              options: RepositoryFetchOptions())
        
        checkOperation.completionBlock = { [weak self] in
            let result: Result<AccountItem?, Swift.Error>
            do {
                let existingAccount = try checkOperation.extractNoCancellableResultData()
                if let recoveryAccount = self?.recoveryAccount {
                    guard
                        let existingAccount,
                        Self.isValidRecoveryReplacement(
                            item,
                            expected: recoveryAccount,
                            existing: existingAccount,
                            keystore: Keychain()
                        )
                    else {
                        result = .failure(AccountCreateError.invalidSeed)
                        DispatchQueue.main.async { completion?(result) }
                        return
                    }
                    result = .success(item)
                } else if existingAccount == nil {
                    result = .success(item)
                } else {
                    result = .failure(AccountCreateError.duplicated)
                }
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                completion?(result)
            }
        }
        
        operationManager.enqueue(operations: [checkOperation], in: .sync)
    }

    static func isValidRecoveryReplacement(
        _ candidate: AccountItem,
        expected: AccountItem,
        existing: AccountItem,
        keystore: KeystoreProtocol
    ) -> Bool {
        guard
            candidate.address == expected.address,
            candidate.publicKeyData == expected.publicKeyData,
            candidate.networkType == expected.networkType,
            candidate.cryptoType == expected.cryptoType,
            existing.address == expected.address,
            existing.publicKeyData == expected.publicKeyData,
            existing.networkType == expected.networkType,
            existing.cryptoType == expected.cryptoType
        else {
            return false
        }

        return SelectedWalletSettings.hasVerifiedSigningKey(
            keystore: keystore,
            account: candidate
        )
    }

    override func importAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>, completion: ((Result<AccountItem, Swift.Error>?) -> Void)?) {
        importOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch importOperation.result {
                case .success(let accountItem):
                    self?.importAccountItem(accountItem, completion: completion)
                case .failure(let error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [importOperation], in: .sync)
    }
    
    override func validateAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>, completion: ((Result<AccountItem?, Error>?) -> Void)?) {
        importOperation.completionBlock = { [weak self] in
            switch importOperation.result {
            case .success(let accountItem):
                self?.validateAccountItem(accountItem, completion: completion)
            case .failure(let error):
                self?.presenter?.didReceiveAccountImport(error: error)
            case .none:
                let error = BaseOperationError.parentOperationCancelled
                self?.presenter?.didReceiveAccountImport(error: error)
            }
        }
        
        operationManager.enqueue(operations: [importOperation], in: .sync)
    }
}
