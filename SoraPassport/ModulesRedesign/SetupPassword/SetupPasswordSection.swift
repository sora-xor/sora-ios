import Foundation

class SetupPasswordSection {
    var id = UUID()
    var items: [SetupPasswordSectionItem]
    
    init(items: [SetupPasswordSectionItem]) {
        self.items = items
    }
}

enum SetupPasswordSectionItem: Hashable {
    case setupPassword(SetupPasswordItem)
}

extension SetupPasswordSection: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SetupPasswordSection, rhs: SetupPasswordSection) -> Bool {
        lhs.id == rhs.id
    }
}
