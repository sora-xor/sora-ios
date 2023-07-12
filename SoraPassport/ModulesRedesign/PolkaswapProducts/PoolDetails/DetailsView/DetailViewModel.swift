import Foundation
import CommonWallet
import SoraUIKit

enum DetailsType {
    case casual
    case progress(Float)
}

final class DetailViewModel {

    let title: String
    var infoHandler: (() -> Void)?
    let rewardAssetImage: String?
    let statusAssetImage: UIImage?
    let assetAmountText: SoramitsuTextItem
    let fiatAmountText: SoramitsuTextItem?
    let type: DetailsType

    init(title: String,
         rewardAssetImage: String? = nil,
         statusAssetImage: UIImage? = nil,
         assetAmountText: SoramitsuTextItem,
         fiatAmountText: SoramitsuTextItem? = nil,
         type: DetailsType = .casual) {
        self.title = title
        self.rewardAssetImage = rewardAssetImage
        self.statusAssetImage = statusAssetImage
        self.assetAmountText = assetAmountText
        self.fiatAmountText = fiatAmountText
        self.type = type
    }
}
