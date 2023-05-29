import Foundation
import SoraUIKit
import CommonWallet
import RobinHood

final class ConfirmAssetViewModel {
    let imageViewModel: WalletImageViewModelProtocol?
    var amountText: String
    let symbol: String
    
    init(imageViewModel: WalletImageViewModelProtocol?, amountText: String, symbol: String) {
        self.imageViewModel = imageViewModel
        self.amountText = amountText
        self.symbol = symbol
    }
}

final class ConfirmAssetsItem: NSObject {
    
    let firstAssetImageModel: ConfirmAssetViewModel
    let secondAssetImageModel: ConfirmAssetViewModel
    let operationImageName: String
    
    init(firstAssetImageModel: ConfirmAssetViewModel,
         secondAssetImageModel: ConfirmAssetViewModel,
         operationImageName: String) {
        self.firstAssetImageModel = firstAssetImageModel
        self.secondAssetImageModel = secondAssetImageModel
        self.operationImageName = operationImageName
    }
}

extension ConfirmAssetsItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { ConfirmAssetsCell.self }
    
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    
    var clipsToBounds: Bool { false }
}
