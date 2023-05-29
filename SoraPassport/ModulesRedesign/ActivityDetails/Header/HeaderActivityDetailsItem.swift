import Foundation
import SoraUIKit
import CommonWallet

final class HeaderActivityDetailsItem: NSObject {

    let typeText: String
    let typeTransactionImage: UIImage?
    let actionTransactionImage: UIImage?
    let firstAssetImageViewModel: WalletImageViewModelProtocol?
    let secondAssetImageViewModel: WalletImageViewModelProtocol?
    let firstBalanceText: NSAttributedString
    let secondBalanceText: NSAttributedString?
    var details: [DetailViewModel]

    init(typeText: String,
         typeTransactionImage: UIImage?,
         actionTransactionImage: UIImage? = nil,
         firstAssetImageViewModel: WalletImageViewModelProtocol?,
         secondAssetImageViewModel: WalletImageViewModelProtocol? = nil,
         firstBalanceText: NSAttributedString,
         secondBalanceText: NSAttributedString? = nil,
         details: [DetailViewModel]) {
        self.typeText = typeText
        self.typeTransactionImage = typeTransactionImage
        self.actionTransactionImage = actionTransactionImage
        self.firstAssetImageViewModel = firstAssetImageViewModel
        self.secondAssetImageViewModel = secondAssetImageViewModel
        self.firstBalanceText = firstBalanceText
        self.secondBalanceText = secondBalanceText
        self.details = details
    }
}

extension HeaderActivityDetailsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { HeaderActivityDetailsCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
}
