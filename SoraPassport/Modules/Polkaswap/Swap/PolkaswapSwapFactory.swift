import CommonWallet
import Foundation

final class PolkaswapSwapFactory: PolkaswapSwapFactoryProtocol {
    var assetManager: AssetManagerProtocol
    var amountFormatterFactory: AmountFormatterFactoryProtocol

    init(assetManager: AssetManagerProtocol, amountFormatterFactory: AmountFormatterFactoryProtocol) {
        self.assetManager = assetManager
        self.amountFormatterFactory = amountFormatterFactory
    }

    func createAssetImageViewModel(asset: AssetInfo) -> WalletImageViewModelProtocol? {
        if let iconString = asset.icon {
            return WalletSvgImageViewModel(svgString: iconString)
        } else {
            return WalletStaticImageViewModel(staticImage: R.image.assetUnkown()!)
        }
    }

    func createAssetViewModel(asset: AssetInfo?, amount: Decimal?, locale: Locale) -> PolkaswapAssetViewModel {
        guard let asset = asset else {
            return PolkaswapAssetViewModel(isEmpty: true, assetImageViewModel: nil, amountInputViewModel: nil, assetName: nil)
        }
        let assetImageViewModel = createAssetImageViewModel(asset: asset)
        let assetName = asset.symbol
        let formatter = amountFormatterFactory.createInputFormatter(for: asset).value(for: locale)
        var amountInputViewModel = PolkaswapAmountInputViewModel(
            symbol: "",
            amount: amount,
            limit: Decimal(Int.max),
            formatter: formatter,
            precision: 18
        )
        let assetViewModel = PolkaswapAssetViewModel(isEmpty: false,
                                                     assetImageViewModel: assetImageViewModel,
                                                     amountInputViewModel: amountInputViewModel,
                                                     assetName: assetName)
        return assetViewModel
    }
}
