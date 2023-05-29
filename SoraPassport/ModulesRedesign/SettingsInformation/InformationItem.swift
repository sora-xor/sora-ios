import SoraUIKit


final class InformationItem: NSObject {

    enum RightItem {
        case arrow
        case link
    }
    
    enum Position {
        case first
        case middle
        case last
    }

    let title: String
    let subtitle: String?
    let picture: Picture?
    let rightItem: RightItem
    let onTap: (()->())?
    
    public var position: Position = .middle

    init(title: String, subtitle: String? = nil, picture: Picture? = nil, rightItem: RightItem, onTap: (()->())? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.picture = picture
        self.rightItem = rightItem
        self.onTap = onTap
    }
}

extension InformationItem: SoramitsuTableViewItemProtocol {
    
    var cellType: AnyClass { SettingsInformationCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {}
    
}
