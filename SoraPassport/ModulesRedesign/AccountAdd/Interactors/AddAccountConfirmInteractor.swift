import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

class AddAccountConfirmInteractor: BaseAccountConfirmInteractor {
    private(set) var settings: SelectedWalletSettingsProtocol
    let eventCenter: EventCenterProtocol

    private var currentOperation: Operation?

    init(request: AccountCreationRequest,
         mnemonic: IRMnemonicProtocol,
         accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         settings: SelectedWalletSettingsProtocol,
         eventCenter: EventCenterProtocol) {
        self.settings = settings
        self.eventCenter = eventCenter

        super.init(request: request,
                   mnemonic: mnemonic,
                   accountOperationFactory: accountOperationFactory,
                   accountRepository: accountRepository,
                   operationManager: operationManager)
    }

    private func handleResult(_ result: Result<AccountItem, Error>?) {
        switch result {
        case .success(let accountItem):
            settings.save(value: accountItem)
            eventCenter.notify(with: SelectedAccountChanged())

            presenter?.didCompleteConfirmation(for: accountItem)
        case .failure(let error):
            presenter?.didReceive(error: error)
        case .none:
            let error = BaseOperationError.parentOperationCancelled
            presenter?.didReceive(error: error)
        }
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

                self?.handleResult(connectionOperation.result)
            }
        }

        operationManager.enqueue(operations: [importOperation, persistentOperation, connectionOperation],
                                 in: .sync)
    }
}
