/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import SoraKeystore

protocol SelectedWalletSettingsProtocol: AnyObject {
    var currentAccount: AccountItem? {get}
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
