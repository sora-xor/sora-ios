import SoraUIKit

final class ContactFooterItem: NSObject {
}

extension ContactFooterItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        ContactFooterCell.self
    }
    
    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }
    
    var clipsToBounds: Bool {
        true
    }
}
