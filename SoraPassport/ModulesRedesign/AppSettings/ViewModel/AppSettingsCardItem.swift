import SoraUIKit

final class AppSettingsCardItem: NSObject {

    let title: String?
    let menuItems: [AppSettingsItem]

    init(title: String?, menuItems: [AppSettingsItem]) {
        self.title = title
        self.menuItems = menuItems
    }
}

extension AppSettingsCardItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AppSettingsCardCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {}
}
