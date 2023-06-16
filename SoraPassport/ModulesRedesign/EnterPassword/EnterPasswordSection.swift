import Foundation

class EnterPasswordSection {
    var id = UUID()
    var items: [EnterPasswordSectionItem]
    
    init(items: [EnterPasswordSectionItem]) {
        self.items = items
    }
}

enum EnterPasswordSectionItem: Hashable {
    case enterPassword(EnterPasswordItem)
}

extension EnterPasswordSection: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: EnterPasswordSection, rhs: EnterPasswordSection) -> Bool {
        lhs.id == rhs.id
    }
}
