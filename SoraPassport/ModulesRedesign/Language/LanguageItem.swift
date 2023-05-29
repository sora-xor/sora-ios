import SoraUIKit

final class LanguageItem: NSObject {
    
    static var itemHeight: CGFloat {
        64
    }

    let title: String
    let subtitle: String
    let code: String
    var selected: Bool
    let onTap: (()->())?

    init(code: String, title: String, subtitle: String, selected: Bool = false, onTap: (()->())? = nil) {
        self.code = code
        self.title = title
        self.subtitle = subtitle
        self.selected = selected
        self.onTap = onTap
    }
}

extension LanguageItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass {
        LanguageCell.self
    }
    
    var backgroundColor: SoramitsuColor {
        .custom(uiColor: .clear)
    }
    
    var clipsToBounds: Bool {
        false
    }
    
    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        return LanguageItem.itemHeight
    }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        onTap?()
    }
}
