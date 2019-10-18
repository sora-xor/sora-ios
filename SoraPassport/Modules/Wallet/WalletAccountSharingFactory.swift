/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

struct WalletAccountSharingFactory: AccountShareFactoryProtocol {
    let assets: [WalletAsset]
    let amountFormatter: NumberFormatter

    func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] {
        var title: String
        var optionalAssetTitle: String?
        var optionalAmountTitle: String?

        if let assetId = receiveInfo.assetId,
            let asset = assets.first(where: { $0.identifier.identifier() == assetId.identifier() }) {
            optionalAssetTitle = asset.details
        }

        if let amount = receiveInfo.amount?.value,
            let amountDecimal = Decimal(string: amount),
            let formattedAmount = amountFormatter.string(from: amountDecimal as NSNumber) {
            optionalAmountTitle = formattedAmount
        }

        if let assetTitle = optionalAssetTitle, let amountTitle = optionalAmountTitle {
            title = R.string.localizable.walletAccountShareAssetAmountMessage(amountTitle, assetTitle)
        } else if let assetTitle = optionalAssetTitle {
            title = R.string.localizable.walletAccountShareAssetOrAmountMessage(assetTitle)
        } else if let amountTitle = optionalAmountTitle {
            title = R.string.localizable.walletAccountShareAssetOrAmountMessage(amountTitle)
        } else {
            title = R.string.localizable.walletAccountShareMessage()
        }

        return [qrImage, title, receiveInfo.accountId.identifier()]
    }
}
