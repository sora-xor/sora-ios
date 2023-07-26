import SoraFoundation
import SoraUIKit
import SSFCloudStorage
import Combine

final class AccountImportedViewModel: AccountImportedViewModelProtocol {
    @Published var title: String = R.string.localizable.importedAccountTitle(preferredLanguages: .currentLocale)
    var titlePublisher: Published<String>.Publisher { $title }
    
    @Published var snapshot: AccountImportedSnapshot = AccountImportedSnapshot()
    var snapshotPublisher: Published<AccountImportedSnapshot>.Publisher { $snapshot }

    private let wireframe: AccountImportedWireframeProtocol
    private let importedAccount: OpenBackupAccount?
    private let backedUpAccounts: [OpenBackupAccount]
    private var endAddingBlock: (() -> Void)?

    init(importedAccountAddress: String,
         backedUpAccounts: [OpenBackupAccount],
         wireframe: AccountImportedWireframeProtocol,
         endAddingBlock: (() -> Void)? = nil) {
        self.importedAccount = backedUpAccounts.first(where: { $0.address == importedAccountAddress })
        self.backedUpAccounts = backedUpAccounts
        self.wireframe = wireframe
        self.endAddingBlock = endAddingBlock
    }
    
    deinit {
        print("deinited")
    }
    
    func reload() {
        title = R.string.localizable.importedAccountTitle(preferredLanguages: languages)
        snapshot = createSnapshot()
    }

    private func createSnapshot() -> AccountImportedSnapshot {
        var snapshot = AccountImportedSnapshot()
        
        let sections = [ contentSection() ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }

    private func contentSection() -> AccountImportedSection {
        let importedAccountsAddresses = ApplicationConfig.shared.backupedAccountAddresses
        let areThereAnotherAccounts = !(Set(backedUpAccounts.map { $0.address }).subtracting(importedAccountsAddresses).isEmpty)
        let item = AccountImportedItem(accountName: importedAccount?.name ?? "",
                                       accountAddress: importedAccount?.address ?? "",
                                       areThereAnotherAccounts: areThereAnotherAccounts )
        item.loadMoreTapHandler = { [weak self] in
            let notBackedUpAccount = self?.backedUpAccounts.filter { !ApplicationConfig.shared.backupedAccountAddresses.contains($0.address) }
            self?.wireframe.showBackepedAccounts(accounts: notBackedUpAccount ?? [])
        }
        item.continueTapHandler = { [weak self] in
            if self?.endAddingBlock != nil {
                self?.wireframe.dissmiss(completion: self?.endAddingBlock)
                return
            }
            self?.wireframe.showSetupPinCode()
        }
        return AccountImportedSection(items: [ .accountImported(item) ])
    }
}

extension AccountImportedViewModel: Localizable {
    private var languages: [String]? {
        LocalizationManager.shared.preferredLocalizations
    }

    func applyLocalization() {
        reload()
    }
}
