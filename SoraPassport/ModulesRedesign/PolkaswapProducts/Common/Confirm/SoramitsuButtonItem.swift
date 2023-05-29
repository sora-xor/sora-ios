import Foundation
import SoraUIKit

final class SoramitsuButtonItem: NSObject {
    
    var title: SoramitsuTextItem
    let buttonBackgroudColor: SoramitsuColor?
    var handler: (() -> Void)?
    var isEnable: Bool
    
    init(title: SoramitsuTextItem, buttonBackgroudColor: SoramitsuColor? = nil, isEnable: Bool = true, handler: (() -> Void)?) {
        self.title = title
        self.buttonBackgroudColor = buttonBackgroudColor
        self.handler = handler
        self.isEnable = isEnable
    }
}

extension SoramitsuButtonItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { SoramitsuButtonCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
}
