import SoraUIKit

final class FriendsItem: NSObject {
    
    var onClose: (() -> Void)?
    var onTap: (() -> Void)?
    
    override init() {
        super.init()
    }
}

extension FriendsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { FriendsCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
}
