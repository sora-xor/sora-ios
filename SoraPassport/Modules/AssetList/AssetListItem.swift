import Foundation
import SoraSwiftUI

final class AssetListItem: NSObject {

    var assetInfo: AssetInfo
    var assetViewModel: AssetViewModel
    var favoriteHandle: ((AssetListItem) -> Void)?
    var balance: Decimal

    init(assetInfo: AssetInfo, assetViewModel: AssetViewModel, balance: Decimal) {
        self.assetInfo = assetInfo
        self.assetViewModel = assetViewModel
        self.balance = balance
    }
}

extension AssetListItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AssetListCell.self }

    var backgroundColor: SoramitsuColor { .bgPage }

    var clipsToBounds: Bool { false }

    var canMove: Bool {
        assetInfo.assetId != .xor
    }
}
