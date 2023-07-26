import SoraFoundation
import SoraUIKit
import SSFCloudStorage
import IrohaCrypto
import SoraKeystore

enum EntryPoint {
    case onboarding
    case profile
}

final class SetupPasswordPresenter: SetupPasswordPresenterProtocol {
    @Published var title: String = R.string.localizable.createBackupPasswordTitle(preferredLanguages: .currentLocale)
    var titlePublisher: Published<String>.Publisher { $title }
    
    @Published var snapshot: SetupPasswordSnapshot = SetupPasswordSnapshot()
    var snapshotPublisher: Published<SetupPasswordSnapshot>.Publisher { $snapshot }
    
    weak var view: SetupPasswordViewProtocol?
    var wireframe: SetupPasswordWireframeProtocol?
    private var completion: (() -> Void)? = nil
    private var backupAccount: OpenBackupAccount
    private let cloudStorageService: CloudStorageServiceProtocol
    private var createAccountRequest: AccountCreationRequest?
    private var createAccountService: CreateAccountServiceProtocol?
    private var mnemonic: IRMnemonicProtocol?
    private let entryPoint: EntryPoint
    private let keystore: KeystoreProtocol

    init(account: OpenBackupAccount,
         cloudStorageService: CloudStorageServiceProtocol,
         createAccountRequest: AccountCreationRequest? = nil,
         createAccountService: CreateAccountServiceProtocol? = nil,
         mnemonic: IRMnemonicProtocol? = nil,
         entryPoint: EntryPoint,
         keystore: KeystoreProtocol,
         completion: (() -> Void)? = nil) {
        self.backupAccount = account
        self.completion = completion
        self.createAccountRequest = createAccountRequest
        self.createAccountService = createAccountService
        self.mnemonic = mnemonic
        self.entryPoint = entryPoint
        self.keystore = keystore
        self.cloudStorageService = cloudStorageService
    }
    
    deinit {
        print("deinited")
    }
    
    func reload() {
        title = R.string.localizable.createBackupPasswordTitle(preferredLanguages: languages)
        snapshot = createSnapshot()
    }
    
    func backupAccount(with password: String) {
        if entryPoint == .profile {
            guard let account = SelectedWalletSettings.shared.currentAccount else { return }
    
            updateBackupedAccount(with: account, password: password)
            
            cloudStorageService.saveBackupAccount(account: backupAccount, password: password) { [weak self] result in
                self?.handler(result)
            }
            return
        }
        
        if let createAccountRequest = createAccountRequest, let mnemonic = mnemonic {
            createAccountService?.createAccount(request: createAccountRequest, mnemonic: mnemonic) { [weak self] result in
                guard let self = self, let result = result, case .success(let account) = result else { return }
    
                self.updateBackupedAccount(with: account, password: password)
                
                self.cloudStorageService.saveBackupAccount(account: self.backupAccount, password: password) { [weak self] result in
                    self?.handler(result)
                }
            }
        }
    }

    private func createSnapshot() -> SetupPasswordSnapshot {
        var snapshot = SetupPasswordSnapshot()
        
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }

    private func contentSection() -> SetupPasswordSection {
        let item = SetupPasswordItem()
        item.setupPasswordButtonTapped = { [weak self] password in
            self?.backupAccount(with: password)
        }
        return SetupPasswordSection(items: [ .setupPassword(item) ])
    }
    
    private func handler(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            var backupedAccountAddresses = ApplicationConfig.shared.backupedAccountAddresses
            backupedAccountAddresses.append(backupAccount.address)
            ApplicationConfig.shared.backupedAccountAddresses = backupedAccountAddresses
            
            if completion != nil {
                view?.controller.dismiss(animated: true, completion: completion)
            } else {
                wireframe?.showSetupPinCode()
            }
        case .failure(let error):
            wireframe?.present(message: nil,
                               title: error.localizedDescription,
                               closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                               from: view)
        }
    }
    
    private func updateBackupedAccount(with account: AccountItem, password: String) {
        guard let expectedSeedData = try? keystore.fetchSeedForAddress(account.address) else { return }
        let rawSeed = expectedSeedData.toHex(includePrefix: true)
        
        _ = try? keystore.fetchSecretKeyForAddress(account.address)
        let exportData = try? KeystoreExportWrapper(keystore: keystore).export(account: account, password: password)
        
        backupAccount.address = account.address
        backupAccount.backupAccountTypes = [.json, .seed, .passphrase]
        backupAccount.seed = OpenBackupAccount.Seed(substrateSeed: rawSeed)
        backupAccount.json = OpenBackupAccount.Json(substrateJson: exportData)
    }
}

extension SetupPasswordPresenter: Localizable {
    private var languages: [String]? {
        LocalizationManager.shared.preferredLocalizations
    }

    func applyLocalization() {
        reload()
    }
}
