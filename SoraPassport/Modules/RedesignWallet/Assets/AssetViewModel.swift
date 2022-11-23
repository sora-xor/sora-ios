import Foundation
import UIKit
import CommonWallet
import SoraSwiftUI

struct AssetViewModel {

    let title: String
    let subtitle: String
    let imageViewModel: WalletImageViewModelProtocol?
    var mode: AssetViewMode
    var isFavorite: Bool

    init(title: String, subtitle: String, imageViewModel: WalletImageViewModelProtocol?, mode: AssetViewMode = .view, isFavorite: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.imageViewModel = imageViewModel
        self.mode = mode
        self.isFavorite = isFavorite
    }
}
