import SoraUIKit

final class MoreMenuItem: NSObject {

    let title: String
    let subtitle: String
    let picture: Picture?
    let circleColor: SoramitsuColor?
    let onTap: (()->())?

    init(title: String, subtitle: String, picture: Picture?, circleColor: SoramitsuColor? = nil, onTap: (()->())? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.picture = picture
        self.circleColor = circleColor
        self.onTap = onTap
    }
}

extension MoreMenuItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { MoreMenuCell.self }
    var backgroundColor: SoramitsuColor { .bgPage }
    var clipsToBounds: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
}
