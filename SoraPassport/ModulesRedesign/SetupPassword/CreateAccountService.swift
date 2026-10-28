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
        let operation = accountOperationFactory.newAccountOperation(request: request, mnemonic: mnemonic)
        guard currentOperation == nil else {
            return
        }

        let persistentOperation = accountRepository.saveOperation({
            let accountItem = try operation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return [accountItem]
        }, { [] })

        persistentOperation.addDependency(operation)

        let connectionOperation: BaseOperation<AccountItem> = ClosureOperation {
            let accountItem = try operation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return accountItem
        }

        connectionOperation.addDependency(persistentOperation)

        currentOperation = connectionOperation

        connectionOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.currentOperation = nil

                switch connectionOperation.result {
                case .success(let accountItem):
                    self?.settings.save(value: accountItem)
                    self?.eventCenter.notify(with: SelectedAccountChanged())
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    completion(.failure(error))
                case .some(.failure(_)):
                    break
                }
                
                completion(connectionOperation.result)
            }
        }

        operationManager.enqueue(operations: [operation, persistentOperation, connectionOperation], in: .sync)
    }
}


