import SoraUIKit

final class EnabledItem: NSObject {
    
    var enabledViewModels: [EnabledViewModel] = []
    var title: String
    var onTap: (() -> Void)?
    
    init(title: String) {
        self.title = title
        super.init()
    }
}

extension EnabledItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { EnabledCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
//        onTap?()
    }
}
