import Foundation
import SoraUIKit

final class DiscoverItem: NSObject {

    var handler: (() -> Void)?
}

extension DiscoverItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { DiscoverCell.self }

    var backgroundColor: SoramitsuColor { .bgPage }

    var clipsToBounds: Bool { false }
}
