import SoraUIKit

class BackupedAccountsSection {
    var id = UUID()
    var items: [BackupedAccountSectionItem]
    
    init(items: [BackupedAccountSectionItem]) {
        self.items = items
    }
}

enum BackupedAccountSectionItem: Hashable {
    case account(BackupedAccountItem)
    case space(SoramitsuTableViewSpacerItem)
    case button(SoramitsuButtonItem)
}

extension BackupedAccountsSection: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BackupedAccountsSection, rhs: BackupedAccountsSection) -> Bool {
        lhs.id == rhs.id
    }
}
