import SoraUIKit

final class FriendsItem: NSObject {
    
    var removeViewButtonHandler: (() -> Void)?
    var tapViewHandler: (() -> Void)?
    
    override init() {
        super.init()
    }
}

extension FriendsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { FriendsCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
}
