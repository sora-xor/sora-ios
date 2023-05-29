import Foundation
import SoraUIKit
import CommonWallet
import RobinHood

final class SendAssetItem: NSObject {
    
    let imageViewModel: WalletSvgImageViewModel?
    let symbol: String
    let amount: String
    let balance: String
    let fiat: String
    
    init(imageViewModel: WalletSvgImageViewModel?,
         symbol: String,
         amount: String,
         balance: String,
         fiat: String) {
        self.imageViewModel = imageViewModel
        self.symbol = symbol
        self.amount = amount
        self.balance = balance
        self.fiat = fiat
    }
}

extension SendAssetItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { SendAssetCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
}
