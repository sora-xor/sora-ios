import SoraUIKit

final class AppSettingsItem: NSObject {

    enum SwitcherState {
        case disabled
        case on
        case off
    }

    enum RightItem {
        case arrow
        case switcher(state: SwitcherState)
    }

    let title: String
    let picture: Picture?
    let rightItem: RightItem
    let onTap: (()->())?
    let onSwitch: ((Bool)->())?

    init(title: String, picture: Picture? = nil, rightItem: RightItem, onTap: (()->())? = nil, onSwitch: ((Bool)->())? = nil) {
        self.title = title
        self.picture = picture
        self.rightItem = rightItem
        self.onTap = onTap
        self.onSwitch = onSwitch
    }
}

extension AppSettingsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AppSettingsCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
}
