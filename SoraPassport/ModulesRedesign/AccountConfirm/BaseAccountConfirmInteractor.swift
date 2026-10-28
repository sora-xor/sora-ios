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

import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

class BaseAccountConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    let request: AccountCreationRequest
    let mnemonic: IRMnemonicProtocol
    let shuffledWords: [String]
    let accountOperationFactory: AccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let operationManager: OperationManagerProtocol

    init(request: AccountCreationRequest,
         mnemonic: IRMnemonicProtocol,
         accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol) {
        self.request = request
        self.mnemonic = mnemonic
        self.shuffledWords = mnemonic.allWords().shuffled()
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.operationManager = operationManager
    }

    func createAccountUsingOperation(
        _ importOperation: BaseOperation<PreparedAccount>
    ) {}
}

extension BaseAccountConfirmInteractor: AccountConfirmInteractorInputProtocol {
    func requestWords() {
        presenter.didReceive(words: shuffledWords,
                             afterConfirmationFail: false)
    }

    func confirm(words: [String]) {
        guard words == mnemonic.allWords() else {
            presenter.didReceive(words: shuffledWords,
                                 afterConfirmationFail: true)
            return
        }

        let operation = accountOperationFactory.prepareAccountOperation(
            request: request,
            mnemonic: mnemonic
        )
        createAccountUsingOperation(operation)
    }

    func skipConfirmation() {
        let operation = accountOperationFactory.prepareAccountOperation(
            request: request,
            mnemonic: mnemonic
        )
        createAccountUsingOperation(operation)
    }
}
