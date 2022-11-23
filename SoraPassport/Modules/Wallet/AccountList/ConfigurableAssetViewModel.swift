import Foundation
import CommonWallet
import RobinHood

protocol ConfigurableAssetViewModelProtocol: AssetViewModelProtocol {

}

struct ConfigurableAssetConstants {
    static let cellReuseIdentifier = "co.jp.sora.asset.cell.identifier"
    static let cellHeight: CGFloat = 96.0
}

final class ConfigurableAssetViewModel: ConfigurableAssetViewModelProtocol {
    var details: String
    var cellReuseIdentifier: String { ConfigurableAssetConstants.cellReuseIdentifier }
    var itemHeight: CGFloat { ConfigurableAssetConstants.cellHeight }
    let assetId: String
    let amount: String
    let symbol: String?

    let accessoryDetails: String?
    let imageViewModel: WalletImageViewModelProtocol?
    let style: AssetCellStyle
    let command: WalletCommandProtocol?
    let toggleCommand: WalletCommandProtocol?
    let toggleIcon: UIImage?

    init(assetId: String,
         amount: String,
         symbol: String?,
         details: String,
         accessoryDetails: String?,
         imageViewModel: WalletImageViewModelProtocol?,
         style: AssetCellStyle,
         command: WalletCommandProtocol?,
         toggleCommand: WalletCommandProtocol?,
         toggleIcon: UIImage?) {
        self.assetId = assetId
        self.amount = amount
        self.symbol = symbol
        self.details = details
        self.accessoryDetails = accessoryDetails
        self.imageViewModel = imageViewModel
        self.style = style
        self.command = command
        self.toggleCommand = toggleCommand
        self.toggleIcon = toggleIcon
    }
}
