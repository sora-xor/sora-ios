/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood

protocol ConfigurableAssetViewModelProtocol: AssetViewModelProtocol {

}

struct ConfigurableAssetConstants {
    static let cellReuseIdentifier = "co.jp.sora.asset.cell.identifier"
    static let cellHeight: CGFloat = 90.0
}

final class ConfigurableAssetViewModel/*<T: Codable>*/: ConfigurableAssetViewModelProtocol {
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

    init(assetId: String,
         amount: String,
         symbol: String?,
         details: String,
         accessoryDetails: String?,
         imageViewModel: WalletImageViewModelProtocol?,
         style: AssetCellStyle,
         command: WalletCommandProtocol?) {
        self.assetId = assetId
        self.amount = amount
        self.symbol = symbol
        self.details = details
        self.accessoryDetails = accessoryDetails
        self.imageViewModel = imageViewModel
        self.style = style
        self.command = command
    }
}
