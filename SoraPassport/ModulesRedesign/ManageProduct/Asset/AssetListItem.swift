import Foundation
import SoraUIKit

final class AssetListItem: NSObject {

    var assetInfo: AssetInfo
    var assetViewModel: AssetViewModel
    var assetHandler: ((String) -> Void)?
    var favoriteHandle: ((AssetListItem) -> Void)?
    var balance: Decimal
    
    var canFavorite: Bool {
        assetInfo.symbol != .xor
    }

    init(assetInfo: AssetInfo, assetViewModel: AssetViewModel, balance: Decimal) {
        self.assetInfo = assetInfo
        self.assetViewModel = assetViewModel
        self.balance = balance
    }
}

extension AssetListItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AssetListCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }

    var canMove: Bool {
        assetInfo.symbol != .xor
    }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        assetHandler?(assetInfo.identifier)
    }
}

extension AssetListItem: ManagebleItem {
    var title: String {
        assetViewModel.title
    }
}
