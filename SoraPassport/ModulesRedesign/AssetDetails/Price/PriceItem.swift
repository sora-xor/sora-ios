import Foundation
import SoraUIKit

final class PriceItem: NSObject {

    var assetInfo: AssetInfo
    var assetViewModel: AssetViewModel

    init(assetInfo: AssetInfo, assetViewModel: AssetViewModel) {
        self.assetInfo = assetInfo
        self.assetViewModel = assetViewModel
    }
}

extension PriceItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PriceCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
