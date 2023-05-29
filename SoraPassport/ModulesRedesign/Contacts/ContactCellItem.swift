import SoraUIKit

final class ContactCellItem: NSObject {

    let title: String
    let onTap: (()->())?

    init(title: String, onTap: (()->())? = nil) {
        self.title = title
        self.onTap = onTap
    }
}

extension ContactCellItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        ContactCell.self
    }
    
    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }
    
    var clipsToBounds: Bool {
        true
    }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
}
