import Foundation
import UIKit
import CommonWallet
import SoraUIKit

struct AssetViewModel {

    let identifier: String
    let title: String
    let subtitle: String
    let fiatText: String
    let icon: UIImage?
    var mode: WalletViewMode
    var isFavorite: Bool

    init(identifier: String,
         title: String,
         subtitle: String,
         fiatText: String,
         icon: UIImage?,
         mode: WalletViewMode = .view,
         isFavorite: Bool = false) {
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.fiatText = fiatText
        self.icon = icon
        self.mode = mode
        self.isFavorite = isFavorite
    }
}
