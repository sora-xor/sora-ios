import Foundation
import SoraUIKit
import CommonWallet
import RobinHood

final class PoolDetailsItem: NSObject {

    var title: String
    let firstAssetImage: String?
    let secondAssetImage: String?
    let rewardAssetImage: String?
    var detailsViewModel: [DetailViewModel] = []
    var isRemoveLiquidityEnabled: Bool
    var isThereLiquidity: Bool
    var handler: ((Liquidity.TransactionLiquidityType) -> Void)?

    init(title: String,
         firstAssetImage: String?,
         secondAssetImage: String?,
         rewardAssetImage: String?,
         detailsViewModel: [DetailViewModel],
         isRemoveLiquidityEnabled: Bool,
         isThereLiquidity: Bool) {
        self.title = title
        self.firstAssetImage = firstAssetImage
        self.secondAssetImage = secondAssetImage
        self.rewardAssetImage = rewardAssetImage
        self.detailsViewModel = detailsViewModel
        self.isRemoveLiquidityEnabled = isRemoveLiquidityEnabled
        self.isThereLiquidity = isThereLiquidity
    }
}

extension PoolDetailsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PoolDetailsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
