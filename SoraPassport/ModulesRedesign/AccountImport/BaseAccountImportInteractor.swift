import UIKit
import IrohaCrypto
import FearlessUtils
import RobinHood
import SoraKeystore
import SSFCloudStorage

class BaseAccountImportInteractor {
    weak var presenter: AccountImportInteractorOutputProtocol!

    private(set) lazy var jsonDecoder = JSONDecoder()
    private(set) lazy var mnemonicCreator = IRMnemonicCreator()

    let accountOperationFactory: AccountOperationFactoryProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let operationManager: OperationManagerProtocol
    let keystoreImportService: KeystoreImportServiceProtocol
    let supportedNetworks: [Chain]
    let defaultNetwork: Chain
    let cloudStorage: CloudStorageServiceProtocol?

    init(accountOperationFactory: AccountOperationFactoryProtocol,
         accountRepository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol,
         keystoreImportService: KeystoreImportServiceProtocol,
         supportedNetworks: [Chain],
         defaultNetwork: Chain,
         cloudStorage: CloudStorageServiceProtocol?) {
        self.accountOperationFactory = accountOperationFactory
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.keystoreImportService = keystoreImportService
        self.supportedNetworks = supportedNetworks
        self.defaultNetwork = defaultNetwork
        self.cloudStorage = cloudStorage
    }

    private func setupKeystoreImportObserver() {
        keystoreImportService.add(observer: self)
        handleIfNeededKeystoreImport()
    }

    private func handleIfNeededKeystoreImport() {
        if let definition = keystoreImportService.definition {
            keystoreImportService.clear()
            do {
                let jsonData = try JSONEncoder().encode(definition)
                let info = try AccountImportJsonFactory().createInfo(from: definition)

                if let text = String(data: jsonData, encoding: .utf8) {
                    presenter.didSuggestKeystore(text: text, preferredInfo: info)
                }

            } catch {
                presenter.didReceiveAccountImport(error: error)
            }
        }
    }

    private func provideMetadata() {
        let metadata = AccountImportMetadata(availableSources: AccountImportSource.allCases,
                                             defaultSource: .mnemonic,
                                             availableNetworks: supportedNetworks,
                                             defaultNetwork: defaultNetwork,
                                             availableCryptoTypes: CryptoType.allCases,
                                             defaultCryptoType: .sr25519)

        presenter.didReceiveAccountImport(metadata: metadata)
    }

    func importAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {}
}

extension BaseAccountImportInteractor: AccountImportInteractorInputProtocol {
    func setup() {
        provideMetadata()
        setupKeystoreImportObserver()
    }

    func importAccountWithMnemonic(request: AccountImportMnemonicRequest) {
        guard let mnemonic = try? mnemonicCreator.mnemonic(fromList: request.mnemonic) else {
            presenter.didReceiveAccountImport(error: AccountCreateError.invalidMnemonicFormat)
            return
        }

        let creationRequest = AccountCreationRequest(username: request.username,
                                                     type: request.networkType,
                                                     derivationPath: request.derivationPath,
                                                     cryptoType: request.cryptoType)

        let accountOperation = accountOperationFactory.newAccountOperation(request: creationRequest,
                                                                           mnemonic: mnemonic)

        importAccountUsingOperation(accountOperation)
    }

    func importAccountWithSeed(request: AccountImportSeedRequest) {
        let operation = accountOperationFactory.newAccountOperation(request: request)
        importAccountUsingOperation(operation)
    }

    func importAccountWithKeystore(request: AccountImportKeystoreRequest) {
        let operation = accountOperationFactory.newAccountOperation(request: request)
        importAccountUsingOperation(operation)
    }

    func deriveMetadataFromKeystore(_ keystore: String) {
        if
            let data = keystore.data(using: .utf8),
            let definition = try? jsonDecoder.decode(KeystoreDefinition.self, from: data),
            let info = try? AccountImportJsonFactory().createInfo(from: definition) {

            presenter.didSuggestKeystore(text: keystore, preferredInfo: info)
        }
    }
    
    func importBackedupAccount(request: AccountImportBackedupRequest) {
        cloudStorage?.importBackupAccount(account: request.account, password: request.password) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let account):
                let request = AccountImportMnemonicRequest(mnemonic: account.passphrase ?? "",
                                                           username: account.name ?? "",
                                                           networkType: .sora,
                                                           derivationPath: account.derivationPath ?? "",
                                                           cryptoType: CryptoType(rawValue: account.cryptoType ?? 0)!)
                self.importAccountWithMnemonic(request: request)
            case .failure(let error):
                self.presenter.didReceiveAccountImport(error: error)
            }
        }
    }
}

extension BaseAccountImportInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        handleIfNeededKeystoreImport()
    }
}
