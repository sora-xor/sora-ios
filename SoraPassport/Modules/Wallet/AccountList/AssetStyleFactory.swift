import Foundation
import CommonWallet

struct AssetStyleFactory: AssetCellStyleFactoryProtocol {

    func createCellStyle(for asset: WalletAsset) -> AssetCellStyle {
            return createXorAssetStyle()
    }

    // MARK: Private

    private func createXorAssetStyle() -> AssetCellStyle {
        let color = UIColor.white
        return commonStyleForLeftBackgroundColor(color)
    }

    private func commonStyleForLeftBackgroundColor(_ leftColor: UIColor) -> AssetCellStyle {
        let shadow = WalletShadowStyle(offset: CGSize(width: 0.0, height: 1.0),
                                       color: UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.35),
                                       opacity: 1.0,
                                       blurRadius: 4.0)

        let textColor = R.color.baseContentPrimary()!
        let headerFont = UIFont.styled(for: .display2, isBold: true)!
        let regularFont = UIFont.styled(for: .paragraph3, isBold: false)!

        let cardStyle = CardAssetStyle(backgroundColor: .white,
                                       leftFillColor: leftColor,
                                       symbol: WalletTextStyle(font: headerFont, color: UIColor.white),
                                       title: WalletTextStyle(font: headerFont, color: textColor),
                                       subtitle: WalletTextStyle(font: regularFont, color: textColor),
                                       accessory: WalletTextStyle(font: headerFont, color: textColor),
                                       shadow: shadow,
                                       cornerRadius: 10.0)

        return .card(cardStyle)
    }
}
