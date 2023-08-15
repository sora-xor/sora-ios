import SoraUIKit

final class EditViewItem: NSObject {
    var onTap: (() -> Void)?
    
    override init() {
        super.init()
    }
}

extension EditViewItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { EditViewCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
}

