// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import RobinHood
import IrohaCrypto

protocol CreateAccountServiceProtocol {
    func createAccount(request: AccountCreationRequest,
                       mnemonic: IRMnemonicProtocol,
                       completion: @escaping (Result<AccountItem, Error>?) -> Void)
}

final class CreateAccountService: CreateAccountServiceProtocol {
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let accountOperationFactory: AccountOperationFactoryProtocol
    let settings: SelectedWalletSettingsProtocol
    let eventCenter: EventCenterProtocol
    let operationManager: OperationManagerProtocol = OperationManager()
    private var currentOperation: Operation?
    
    init(accountRepository: AnyDataProviderRepository<AccountItem>,
         accountOperationFactory: AccountOperationFactoryProtocol,
         settings: SelectedWalletSettingsProtocol,
         eventCenter: EventCenterProtocol) {
        self.accountRepository = accountRepository
        self.accountOperationFactory = accountOperationFactory
        self.settings = settings
        self.eventCenter = eventCenter
    }
    
    func createAccount(request: AccountCreationRequest,
                       mnemonic: IRMnemonicProtocol,
                       completion: @escaping (Result<AccountItem, Error>?) -> Void) {
        guard currentOperation == nil else {
            DispatchQueue.main.async {
                completion(.failure(WalletNetworkMigrationError.lifecycleMutationBusy))
            }
            return
        }
        let operation = accountOperationFactory.prepareAccountOperation(
            request: request,
            mnemonic: mnemonic
        )
        let lifecycleCoordinator = WalletLifecycleCoordinator.shared
        let lifecycleOperation =
            lifecycleCoordinator.makeAcquireOperation()
        operation.addDependency(lifecycleOperation)

        currentOperation = operation
        let selectionEventCenter = eventCenter

        operation.completionBlock = { [weak self] in
            let leaseResult = Result {
                try lifecycleOperation.extractNoCancellableResultData()
            }
            let preparedResult = Result {
                try operation.extractNoCancellableResultData()
            }
            guard let self else {
                try? preparedResult.get().discard()
                try? leaseResult.get().release()
                DispatchQueue.main.async {
                    completion(
                        .failure(
                            WalletNetworkMigrationError
                                .lifecycleMutationBusy
                        )
                    )
                }
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
                    lifecycleLease.release()
                    DispatchQueue.main.async {
                        self?.currentOperation = nil
                        switch result {
                        case let .success(accountItem):
                            selectionEventCenter.notify(
                                with: SelectedAccountChanged(),
                                completionOnMain: {
                                    completion(.success(accountItem))
                                }
                            )
                        case let .failure(error):
                            completion(.failure(error))
                        }
                    }
                }
            } catch {
                try? preparedResult.get().discard()
                try? leaseResult.get().release()
                DispatchQueue.main.async { [weak self] in
                    self?.currentOperation = nil
                    completion(.failure(error))
                }
            }
        }

        lifecycleCoordinator.enqueueOwnedAcquireOperation(
            lifecycleOperation
        )
        operationManager.enqueue(
            operations: [
                operation,
            ],
            in: .sync
        )
    }
}
