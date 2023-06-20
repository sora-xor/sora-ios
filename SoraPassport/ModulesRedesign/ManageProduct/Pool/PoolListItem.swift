import Foundation
import SoraUIKit

final class PoolListItem: NSObject {

    var poolInfo: PoolInfo
    var poolViewModel: PoolViewModel
    var tapHandler: (() -> Void)?
    var favoriteHandle: ((PoolListItem) -> Void)?

    init(poolInfo: PoolInfo, poolViewModel: PoolViewModel) {
        self.poolInfo = poolInfo
        self.poolViewModel = poolViewModel
    }
}

extension PoolListItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PoolListCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }

    var canMove: Bool { false }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        tapHandler?()
    }
}

extension PoolListItem: ManagebleItem {
    var title: String {
        poolViewModel.title
    }
}
