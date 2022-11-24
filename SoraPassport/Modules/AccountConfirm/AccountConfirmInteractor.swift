/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

class AccountConfirmInteractor: BaseAccountConfirmInteractor {
    private(set) var settings: SelectedWalletSettingsProtocol
    private var currentOperation: Operation?

    init(request: AccountCreationRequest,
         mnemonic: IRMnemonicProtocol,
         accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         settings: SelectedWalletSettingsProtocol,
         operationManager: OperationManagerProtocol) {
        self.settings = settings

        super.init(request: request,
                   mnemonic: mnemonic,
                   accountOperationFactory: accountOperationFactory,
                   accountRepository: accountRepository,
                   operationManager: operationManager)
    }

    override func createAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {
        guard currentOperation == nil else {
            return
        }

        let persistentOperation = accountRepository.saveOperation({
            let accountItem = try importOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return [accountItem]
        }, { [] })

        persistentOperation.addDependency(importOperation)

        let connectionOperation: BaseOperation<AccountItem> = ClosureOperation {
            let accountItem = try importOperation
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
                    self?.presenter?.didCompleteConfirmation()
                case .failure(let error):
                    self?.presenter?.didReceive(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [importOperation, persistentOperation, connectionOperation],
                                 in: .sync)
    }
}
