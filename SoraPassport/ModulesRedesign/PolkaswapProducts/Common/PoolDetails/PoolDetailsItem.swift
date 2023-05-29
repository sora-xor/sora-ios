import Foundation
import SoraUIKit
import CommonWallet
import RobinHood

final class PoolDetailsItem: NSObject {

    var title: String
    let firstAssetImage: WalletImageViewModelProtocol?
    let secondAssetImage: WalletImageViewModelProtocol?
    let rewardAssetImage: WalletImageViewModelProtocol?
    var detailsViewModel: [DetailViewModel] = []
    var handler: ((Liquidity.TransactionLiquidityType) -> Void)?

    init(title: String,
         firstAssetImage: WalletImageViewModelProtocol?,
         secondAssetImage: WalletImageViewModelProtocol?,
         rewardAssetImage: WalletImageViewModelProtocol?,
         detailsViewModel: [DetailViewModel]) {
        self.title = title
        self.firstAssetImage = firstAssetImage
        self.secondAssetImage = secondAssetImage
        self.rewardAssetImage = rewardAssetImage
        self.detailsViewModel = detailsViewModel
    }
}

extension PoolDetailsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { PoolDetailsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
