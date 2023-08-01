import Foundation
import UIKit
import CommonWallet
import SoraUIKit

struct EnabledViewModel {
    
    let title: String
    let icon: UIImage?
    var mode: WalletViewMode
    
    init(title: String,
         icon: UIImage?,
         mode: WalletViewMode = .view) {
        self.title = title
        self.icon = icon
        self.mode = mode
    }
}
