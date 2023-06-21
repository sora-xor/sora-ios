import SoraUIKit

final class AccountMenuItem: NSObject {
    
    static var itemHeight: CGFloat {
        72
    }
    
    let title: String
    let image: UIImage?
    var isSelected: Bool
    var isMultiselectionMode: Bool
    let onTap: (() -> ())?
    let onMore: (() -> ())?
    
    init(title: String,
         image: UIImage?,
         isSelected: Bool,
         isMultiselectionMode: Bool,
         onTap: (()->())? = nil,
         onMore: (()->())? = nil) {
        self.title = title
        self.image = image
        self.isSelected = isSelected
        self.isMultiselectionMode = isMultiselectionMode
        self.onTap = onTap
        self.onMore = onMore
    }
    
}

extension AccountMenuItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        AccountTableViewCell.self
    }
    
    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }
    
    var clipsToBounds: Bool {
        false
    }
    
    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        return AccountMenuItem.itemHeight
    }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
    
    func itemActionMore(with context: SoramitsuTableViewContext?) {
        onMore?()
    }
}
