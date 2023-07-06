import SoraFoundation
import SoraUIKit
import SSFCloudStorage

final class SetupPasswordPresenter: SetupPasswordPresenterProtocol {
    @Published var title: String = R.string.localizable.createBackupPasswordTitle(preferredLanguages: .currentLocale)
    var titlePublisher: Published<String>.Publisher { $title }
    
    @Published var snapshot: SetupPasswordSnapshot = SetupPasswordSnapshot()
    var snapshotPublisher: Published<SetupPasswordSnapshot>.Publisher { $snapshot }
    
    weak var view: SetupPasswordViewProtocol?
    var wireframe: SetupPasswordWireframeProtocol?
    private var completion: (() -> Void)? = nil
    private let account: OpenBackupAccount
    private let cloudStorageService: CloudStorageServiceProtocol

    init(account: OpenBackupAccount,
         cloudStorageService: CloudStorageServiceProtocol,
         completion: (() -> Void)? = nil) {
        self.account = account
        self.completion = completion
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
        cloudStorageService.saveBackupAccount(account: account, password: password) { [weak self] result in
            self?.handler(result)
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
            backupedAccountAddresses.append(account.address)
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
}

extension SetupPasswordPresenter: Localizable {
    private var languages: [String]? {
        LocalizationManager.shared.preferredLocalizations
    }

    func applyLocalization() {
        reload()
    }
}
