import SoraUIKit

final class EnabledItem: NSObject {
    var title: String
    var isEnabled: Bool
    var onTap: (() -> Void)?
    
    init(title: String,
         isEnabled: Bool) {
        self.title = title
        self.isEnabled = isEnabled
        super.init()
    }
}

extension EnabledItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { EditViewCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
}
