import Foundation
import UIKit
import CommonWallet
import SoraUIKit

struct PoolViewModel {

    let identifier: String
    let title: String
    let subtitle: String
    let fiatText: String
    let baseAssetImage: UIImage?
    let targetAssetImage: UIImage?
    let rewardAssetImage: UIImage?
    var mode: WalletViewMode
    var isFavorite: Bool

    init(identifier: String,
         title: String,
         subtitle: String,
         fiatText: String,
         baseAssetImage: UIImage?,
         targetAssetImage: UIImage?,
         rewardAssetImage: UIImage?,
         mode: WalletViewMode = .view,
         isFavorite: Bool = false) {
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.fiatText = fiatText
        self.baseAssetImage = baseAssetImage
        self.targetAssetImage = targetAssetImage
        self.rewardAssetImage = rewardAssetImage
        self.mode = mode
        self.isFavorite = isFavorite
    }
}
