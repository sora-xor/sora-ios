import Foundation
import SoraUIKit

final class ConfirmOptionsItem: NSObject {

    var toleranceText: String
    var market: LiquiditySourceType?

    init(toleranceText: String, market: LiquiditySourceType? = nil) {
        self.toleranceText = toleranceText
        self.market = market
    }
}

extension ConfirmOptionsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ConfirmOptionsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
