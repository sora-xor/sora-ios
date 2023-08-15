import SoraUIKit

final class EnabledItem: NSObject {
    
    var enabledViewModels: [EnabledViewModel] = []
    var onTap: ((Int) -> Void)?
    
    override init() {
        super.init()
    }
}

extension EnabledItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { EnabledCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
}
