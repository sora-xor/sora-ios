import SoraUIKit

final class ContactHeaderCellItem: NSObject {

    let title: String
    let onTap: (()->())?

    init(title: String, onTap: (()->())? = nil) {
        self.title = title
        self.onTap = onTap
    }
}

extension ContactHeaderCellItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        ContactHeaderCell.self
    }
    
    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }
    
    var clipsToBounds: Bool {
        true
    }
}
