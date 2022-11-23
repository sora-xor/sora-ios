/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import RobinHood

final class ChangeAccountInteractor {
    weak var presenter: ChangeAccountInteractorOutputProtocol!
    
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let operationManager: OperationManagerProtocol

    init(accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol) {
        self.accountRepository = accountRepository
        self.operationManager = operationManager
    }
}

extension ChangeAccountInteractor: ChangeAccountInteractorInputProtocol {
    func getAccounts() {
        let persistentOperation = accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        
        persistentOperation.completionBlock = { [weak self] in
            guard let accounts = try? persistentOperation.extractNoCancellableResultData() else { return }
            
            DispatchQueue.main.async {
                self?.presenter?.received(accounts: accounts)
            }
        }
        OperationManagerFacade.runtimeBuildingQueue.addOperation(persistentOperation)
    }
}
