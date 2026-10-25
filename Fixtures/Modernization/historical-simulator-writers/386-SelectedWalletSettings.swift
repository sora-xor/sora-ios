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
    func performSetup(completionClosure: @escaping (Result<AccountItem?, Error>) -> Void)
    func save(value: AccountItem)
}

final class SelectedWalletSettings: PersistentValueSettings<AccountItem>, SelectedWalletSettingsProtocol {
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
                completionClosure(.success(result))
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
    var currentAccount: AccountItem? {
        return value
    }
}
