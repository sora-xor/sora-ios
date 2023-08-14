import Foundation

final class EnabledSection {
    var id = UUID()
    var items: [EnabledSectionItem]
    
    init(items: [EnabledSectionItem]) {
        self.items = items
    }
}

enum EnabledSectionItem: Hashable {
    case enabled(EnabledItem)
}

extension EnabledSection: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: EnabledSection, rhs: EnabledSection) -> Bool {
        lhs.id == rhs.id
    }
}
