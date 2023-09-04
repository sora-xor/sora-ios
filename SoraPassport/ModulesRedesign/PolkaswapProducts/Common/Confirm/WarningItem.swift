import Foundation
import SoraUIKit

final class WarningItem: NSObject {}

extension WarningItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { WarningCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
