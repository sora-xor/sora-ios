import UIKit
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCloudStorage

final class AccountCreateInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let mnemonicCreator: IRMnemonicCreatorProtocol
    let supportedNetworkTypes: [Chain]
    let defaultNetwork: Chain
    let accountOperationFactory: AccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let settings: SelectedWalletSettingsProtocol
    let eventCenter: EventCenterProtocol
    let operationManager: OperationManagerProtocol = OperationManager()
    var cloudStorageService: CloudStorageServiceProtocol?
    private var currentOperation: Operation?

    init(mnemonicCreator: IRMnemonicCreatorProtocol,
         supportedNetworkTypes: [Chain],
         defaultNetwork: Chain,
         accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         settings: SelectedWalletSettingsProtocol,
         eventCenter: EventCenterProtocol,
         cloudStorageService: CloudStorageServiceProtocol) {
        self.mnemonicCreator = mnemonicCreator
        self.supportedNetworkTypes = supportedNetworkTypes
        self.defaultNetwork = defaultNetwork
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.settings = settings
        self.cloudStorageService = cloudStorageService
        self.eventCenter = eventCenter
    }
    
    private func handleResult(_ result: Result<AccountItem, Error>?) {
        switch result {
        case .success(let accountItem):
            settings.save(value: accountItem)
            eventCenter.notify(with: SelectedAccountChanged())

            presenter.didCompleteConfirmation(for: accountItem)
        case .failure(let error):
            presenter.didReceive(error: error)
        case .none:
            let error = BaseOperationError.parentOperationCancelled
            presenter.didReceive(error: error)
        }
    }
}

extension AccountCreateInteractor: AccountCreateInteractorInputProtocol {
    func setup() {
        do {
            let mnemonic = try mnemonicCreator.randomMnemonic(.entropy128)

            let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                   availableNetworks: supportedNetworkTypes,
                                                   defaultNetwork: defaultNetwork,
                                                   availableCryptoTypes: CryptoType.allCases,
                                                   defaultCryptoType: .sr25519)
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
    
    func skipConfirmation(request: AccountCreationRequest,
                          mnemonic: IRMnemonicProtocol) {
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

                self?.handleResult(connectionOperation.result)
            }
        }

        operationManager.enqueue(operations: [operation, persistentOperation, connectionOperation], in: .sync)
    }
}

class AccountBackupInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let keystore: KeystoreProtocol
    let mnemonicCreator: IRMnemonicCreatorProtocol
    let account: AccountItem
    var cloudStorageService: CloudStorageServiceProtocol?

    init(keystore: KeystoreProtocol,
         mnemonicCreator: IRMnemonicCreatorProtocol,
         account: AccountItem) {
        self.keystore = keystore
        self.mnemonicCreator = mnemonicCreator
        self.account = account
    }
}

extension AccountBackupInteractor: AccountCreateInteractorInputProtocol {
    private func loadPhrase() throws -> IRMnemonicProtocol {
        let entropy = try keystore.fetchEntropyForAddress(account.address)
        let mnemonic = try mnemonicCreator.mnemonic(fromEntropy: entropy!)
        return mnemonic
    }

    func setup() {
        do {
            let mnemonic = try loadPhrase()

            let metadata = AccountCreationMetadata(mnemonic: mnemonic.allWords(),
                                                   availableNetworks: Chain.allCases,
                                                   defaultNetwork: .sora,
                                                   availableCryptoTypes: CryptoType.allCases,
                                                   defaultCryptoType: .sr25519)
            presenter.didReceive(metadata: metadata)
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
    
    func skipConfirmation(request: AccountCreationRequest, mnemonic: IRMnemonicProtocol) {}
}
