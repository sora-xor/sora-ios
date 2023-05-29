import Foundation
import SoraUIKit

final class ActivityErrorItem: NSObject {

    var handler: (() -> Void)?
}

extension ActivityErrorItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ActivityErrorCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
