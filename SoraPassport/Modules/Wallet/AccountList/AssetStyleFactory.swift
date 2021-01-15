/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

struct AssetStyleFactory: AssetCellStyleFactoryProtocol {
    let xorAssetId: String
    let valAssetId: String
    let ethAssetId: String

    func createCellStyle(for asset: WalletAsset) -> AssetCellStyle {
        if asset.identifier == ethAssetId {
            return createEthAssetStyle()
        } else {
            return createXorAssetStyle()
        }
    }

    // MARK: Private

    private func createEthAssetStyle() -> AssetCellStyle {
        let color = UIColor.white//(red: 0.961, green: 0.969, blue: 0.973, alpha: 1)
        return commonStyleForLeftBackgroundColor(color)
    }

    private func createXorAssetStyle() -> AssetCellStyle {
        let color = UIColor.white//(red: 0.961, green: 0.969, blue: 0.973, alpha: 1)//UIColor(red: 0.816, green: 0.008, blue: 0.107, alpha: 1)
        return commonStyleForLeftBackgroundColor(color)
    }

    private func commonStyleForLeftBackgroundColor(_ leftColor: UIColor) -> AssetCellStyle {
        let shadow = WalletShadowStyle(offset: CGSize(width: 0.0, height: 5.0),
                                       color: UIColor(red: 0, green: 0, blue: 0, alpha: 0.1),
                                       opacity: 1.0,
                                       blurRadius: 25.0)

        let textColor = UIColor(red: 0.176, green: 0.161, blue: 0.149, alpha: 1)
        let headerFont = R.font.soraRc0040417SemiBold(size: 18)!
        let regularFont = R.font.soraRc0040417Regular(size: 14)!

        let cardStyle = CardAssetStyle(backgroundColor: .white,
                                       leftFillColor: leftColor,
                                       symbol: WalletTextStyle(font: headerFont, color: UIColor.white),
                                       title: WalletTextStyle(font: headerFont, color: textColor),
                                       subtitle: WalletTextStyle(font: regularFont, color: textColor),
                                       accessory: WalletTextStyle(font: regularFont, color: textColor),
                                       shadow: shadow,
                                       cornerRadius: 10.0)

        return .card(cardStyle)
    }
}
