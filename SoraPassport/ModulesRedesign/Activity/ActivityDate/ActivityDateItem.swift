import Foundation
import SoraUIKit

final class ActivityDateItem: NSObject {

    var text: String
    var isFirstSection = false

    init(text: String) {
        self.text = text
    }
}

extension ActivityDateItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ActivityDateCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
