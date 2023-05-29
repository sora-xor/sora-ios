import Foundation
import SoraUIKit

final class SoraTextItem: NSObject {
    
    let text: NSAttributedString
    
    init(text: NSAttributedString) {
        self.text = text
    }
}

extension SoraTextItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { SoraTextCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
}
