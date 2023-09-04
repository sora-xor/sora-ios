import Foundation

class AccountImportedSection {
    var id = UUID()
    var items: [AccountImportedSectionItem]
    
    init(items: [AccountImportedSectionItem]) {
        self.items = items
    }
}

enum AccountImportedSectionItem: Hashable {
    case accountImported(AccountImportedItem)
}

extension AccountImportedSection: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AccountImportedSection, rhs: AccountImportedSection) -> Bool {
        lhs.id == rhs.id
    }
}
