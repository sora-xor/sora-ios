import Foundation
import UIKit
import CommonWallet
import SoraUIKit

struct ActivityContentViewModel {
    
    let txHash: String
    let title: String
    let subtitle: String
    let typeTransactionImage: UIImage?
    let firstAssetImageViewModel: WalletImageViewModelProtocol?
    let secondAssetImageViewModel: WalletImageViewModelProtocol?
    let firstBalanceText: NSAttributedString
    let fiatText: String
    let status: TransactionBase.Status
    let isNeedTwoImage: Bool
    
    init(txHash: String,
         title: String,
         subtitle: String,
         typeTransactionImage: UIImage?,
         firstAssetImageViewModel: WalletImageViewModelProtocol?,
         secondAssetImageViewModel: WalletImageViewModelProtocol? = nil,
         firstBalanceText: NSAttributedString,
         fiatText: String,
         status: TransactionBase.Status,
         isNeedTwoImage: Bool = false) {
        self.txHash = txHash
        self.title = title
        self.subtitle = subtitle
        self.typeTransactionImage = typeTransactionImage
        self.firstAssetImageViewModel = firstAssetImageViewModel
        self.secondAssetImageViewModel = secondAssetImageViewModel
        self.firstBalanceText = firstBalanceText
        self.fiatText = fiatText
        self.status = status
        self.isNeedTwoImage = isNeedTwoImage
    }
}
