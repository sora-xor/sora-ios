/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

struct WalletAccountSharingFactory: AccountShareFactoryProtocol {
    let assets: [WalletAsset]
    let amountFormatter: NumberFormatter
    let locale: Locale

    func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] {
        var title: String
        var optionalAssetTitle: String?
        var optionalAmountTitle: String?

        let languages = locale.rLanguages

        if let assetId = receiveInfo.assetId,
            let asset = assets.first(where: { $0.identifier.identifier() == assetId.identifier() }) {
            optionalAssetTitle = asset.details.value(for: locale)
        }

        if let amount = receiveInfo.amount?.value,
            let amountDecimal = Decimal(string: amount),
            let formattedAmount = amountFormatter.string(from: amountDecimal as NSNumber) {
            optionalAmountTitle = formattedAmount
        }

        if let assetTitle = optionalAssetTitle, let amountTitle = optionalAmountTitle {
            title = R.string.localizable
                .walletAccountShareAssetAmountMessage(amountTitle, assetTitle, preferredLanguages: languages)
        } else if let assetTitle = optionalAssetTitle {
            title = R.string.localizable
                .walletAccountShareAssetOrAmountMessage(assetTitle, preferredLanguages: languages)
        } else if let amountTitle = optionalAmountTitle {
            title = R.string.localizable
                .walletAccountShareAssetOrAmountMessage(amountTitle, preferredLanguages: languages)
        } else {
            title = R.string.localizable
                .walletAccountShareMessage(preferredLanguages: languages)
        }

        return [qrImage, title, receiveInfo.accountId.identifier()]
    }
}
