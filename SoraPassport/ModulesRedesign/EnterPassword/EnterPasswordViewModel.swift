import SoraFoundation
import SoraUIKit
import SSFCloudStorage
import RobinHood

final class EnterPasswordViewModel {
    @Published var title: String = R.string.localizable.enterBackupPasswordTitle(preferredLanguages: .currentLocale)
    var titlePublisher: Published<String>.Publisher { $title }
    
    @Published var snapshot: EnterPasswordSnapshot = EnterPasswordSnapshot()
    var snapshotPublisher: Published<EnterPasswordSnapshot>.Publisher { $snapshot }
    
    private var wireframe: EnterPasswordWireframeProtocol?
    private var interactor: AccountImportInteractorInputProtocol
    private var errorText = ""
    private let selectedAccount: OpenBackupAccount?
    private var backedUpAccounts: [OpenBackupAccount]

    init(selectedAddress: String,
         backedUpAccounts: [OpenBackupAccount],
         interactor: AccountImportInteractorInputProtocol,
         wireframe: EnterPasswordWireframeProtocol) {
        self.selectedAccount = backedUpAccounts.first(where: { $0.address == selectedAddress })
        self.interactor = interactor
        self.backedUpAccounts = backedUpAccounts
        self.wireframe = wireframe
    }
    
    deinit {
        print("deinited")
    }

    private func createSnapshot() -> EnterPasswordSnapshot {
        var snapshot = EnterPasswordSnapshot()
        
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }

    private func contentSection() -> EnterPasswordSection {
        let item = EnterPasswordItem(accountName: selectedAccount?.name ?? "",
                                     accountAddress: selectedAccount?.address ?? "",
                                     errorText: errorText,
                                     continueButtonHandler: checkPassword)
        return EnterPasswordSection(items: [ .enterPassword(item) ])
    }
    
    private func checkPassword(password: String) {
        wireframe?.showActivityIndicator()
        
        guard let selectedAccount = selectedAccount else { return }
        let request = AccountImportBackedupRequest(account: selectedAccount, password: password)
        interactor.importBackedupAccount(request: request)
    }
}

extension EnterPasswordViewModel: EnterPasswordViewModelProtocol {
    func reload() {        
        title = R.string.localizable.enterBackupPasswordTitle(preferredLanguages: languages)
        snapshot = createSnapshot()
    }
}

extension EnterPasswordViewModel: AccountImportInteractorOutputProtocol {
    func didCompleteAccountImport() {
        wireframe?.hideActivityIndicator()
        
        guard let selectedAccount = selectedAccount else { return }
        
        var backupedAccountAddresses = ApplicationConfig.shared.backupedAccountAddresses
        backupedAccountAddresses.append(selectedAccount.address)
        ApplicationConfig.shared.backupedAccountAddresses = backupedAccountAddresses
        
        wireframe?.openSuccessImport(importedAccountAddress: selectedAccount.address, accounts: backedUpAccounts)
    }
    
    func didReceiveAccountImport(error: Error) {
        wireframe?.hideActivityIndicator()
        errorText = error.localizedDescription
        reload()
    }
    
    func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?) {}
    func didReceiveAccountImport(metadata: AccountImportMetadata) {}
}

extension EnterPasswordViewModel: Localizable {
    private var languages: [String]? {
        LocalizationManager.shared.preferredLocalizations
    }

    func applyLocalization() {
        reload()
    }
}
