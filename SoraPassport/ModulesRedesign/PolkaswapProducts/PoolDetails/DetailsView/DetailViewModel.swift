import Foundation
import CommonWallet
import SoraUIKit

final class DetailViewModel {

    let title: String
    var infoHandler: (() -> Void)?
    let rewardAssetImage: WalletImageViewModelProtocol?
    let statusAssetImage: UIImage?
    let assetAmountText: SoramitsuTextItem
    let fiatAmountText: SoramitsuTextItem?

    init(title: String,
         rewardAssetImage: WalletImageViewModelProtocol? = nil,
         statusAssetImage: UIImage? = nil,
         assetAmountText: SoramitsuTextItem,
         fiatAmountText: SoramitsuTextItem? = nil) {
        self.title = title
        self.rewardAssetImage = rewardAssetImage
        self.statusAssetImage = statusAssetImage
        self.assetAmountText = assetAmountText
        self.fiatAmountText = fiatAmountText
    }
}
