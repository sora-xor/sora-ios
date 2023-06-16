import SoraFoundation
import SoraUIKit
import SSFCloudStorage
import RobinHood

final class BackupedAccountsViewModel {
    @Published var title: String = R.string.localizable.selectAccountImport(preferredLanguages: .currentLocale)
    var titlePublisher: Published<String>.Publisher { $title }
    
    @Published var snapshot: BackupedAccountsSnapshot = BackupedAccountsSnapshot()
    var snapshotPublisher: Published<BackupedAccountsSnapshot>.Publisher { $snapshot }
    
    var wireframe: BackupedAccountsWireframeProtocol
    var backedUpAccounts: [OpenBackupAccount]

    init(backedUpAccounts: [OpenBackupAccount], wireframe: BackupedAccountsWireframeProtocol) {
        self.backedUpAccounts = backedUpAccounts
        self.wireframe = wireframe
    }
    
    deinit {
        print("deinited")
    }
    
    private func createSnapshot() -> BackupedAccountsSnapshot {
        var snapshot = BackupedAccountsSnapshot()

        let backedUpAddresses = ApplicationConfig.shared.backupedAccountAddresses
        let accounts = backedUpAddresses.isEmpty ? backedUpAccounts : backedUpAccounts.filter { !ApplicationConfig.shared.backupedAccountAddresses.contains($0.address) }
        
        let sections = [ contentSection(with: accounts) ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }

    private func contentSection(with accounts: [OpenBackupAccount]) -> BackupedAccountsSection {
        var items = accountItems(from: accounts)
        
        items.append(contentsOf: [
            .space(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear))),
            .button(buttonItem())
        ])

        return BackupedAccountsSection(items: items)
    }
    
    private func accountItems(from accounts: [OpenBackupAccount]) -> [BackupedAccountSectionItem] {
        return accounts.enumerated().map { (index, account) in
            var accountItemConfig = BackupedAccountItem.Config(cornerMask: .none,
                                                               cornerRaduis: .zero,
                                                               topOffset: 18,
                                                               bottomOffset: -18)
            
            if index == 0 {
                accountItemConfig = BackupedAccountItem.Config(cornerMask: .top,
                                                               cornerRaduis: .max,
                                                               topOffset: 24,
                                                               bottomOffset: -18)
            }
            
            if index == accounts.count - 1 {
                accountItemConfig = BackupedAccountItem.Config(cornerMask: .bottom,
                                                               cornerRaduis: .max,
                                                               topOffset: 18,
                                                               bottomOffset: -24)
            }
            
            if accounts.count == 1 {
                accountItemConfig = BackupedAccountItem.Config(cornerMask: .all,
                                                               cornerRaduis: .max,
                                                               topOffset: 24,
                                                               bottomOffset: -24)
            }
            
            return .account(BackupedAccountItem(accountName: account.name,
                                                accountAddress: account.address,
                                                config: accountItemConfig))
        }
    }

    private func buttonItem() -> SoramitsuButtonItem {
        let buttonTitle = SoramitsuTextItem(text: R.string.localizable.createNewAccountTitle(preferredLanguages: languages),
                                            fontData: FontType.buttonM,
                                            textColor: .bgSurface,
                                            alignment: .center)
        return SoramitsuButtonItem(title: buttonTitle, buttonBackgroudColor: .accentPrimary, handler: wireframe.showCreateAccount)
    }
}

extension BackupedAccountsViewModel: BackupedAccountsViewModelProtocol {
    func reload() {
        title = R.string.localizable.selectAccountImport(preferredLanguages: languages)
        snapshot = createSnapshot()
    }
    
    func didSelectAccount(with address: String) {
        wireframe.openInputPassword(selectedAddress: address, backedUpAccounts: backedUpAccounts)
    }
}

extension BackupedAccountsViewModel: Localizable {
    private var languages: [String]? {
        LocalizationManager.shared.preferredLocalizations
    }

    func applyLocalization() {
        reload()
    }
}
