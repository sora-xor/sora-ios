import Foundation
import SoraUIKit
import CommonWallet

final class PooledItem: NSObject {

    let assetInfo: AssetInfo
    var poolViewModels: [PoolViewModel]
    var openPoolDetailsHandler: ((String) -> Void)?

    init(assetInfo: AssetInfo, poolViewModels: [PoolViewModel]) {
        self.assetInfo = assetInfo
        self.poolViewModels = poolViewModels
    }
}

extension PooledItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PooledCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
