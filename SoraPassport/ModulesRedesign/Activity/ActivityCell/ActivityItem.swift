import Foundation
import SoraUIKit

final class ActivityItem: NSObject {

    var model: ActivityContentViewModel
    var handler: (() -> Void)?

    init(model: ActivityContentViewModel) {
        self.model = model
    }
}

extension ActivityItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ActivityCell.self }

    var backgroundColor: SoramitsuColor { .bgSurface }

    var clipsToBounds: Bool { true }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        handler?()
    }
}
