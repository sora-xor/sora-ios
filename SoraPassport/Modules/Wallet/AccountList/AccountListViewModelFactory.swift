/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood
import SoraFoundation

final class AccountListViewModelFactory {
    let dataProvider: StreamableProvider<EthereumInit>
    let commandDecorator: WalletCommandDecoratorFactoryProtocol
    let assetCellStyleFactory: AssetCellStyleFactoryProtocol
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let ethAssetId: String
    let valAssetId: String

    weak var commandFactory: WalletCommandFactoryProtocol?

    init(dataProvider: StreamableProvider<EthereumInit>,
         commandDecorator: WalletCommandDecoratorFactoryProtocol,
         assetCellStyleFactory: AssetCellStyleFactoryProtocol,
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         valAssetId: String,
         ethAssetId: String) {
        self.dataProvider = dataProvider
        self.commandDecorator = commandDecorator
        self.assetCellStyleFactory = assetCellStyleFactory
        self.amountFormatterFactory = amountFormatterFactory
        self.ethAssetId = ethAssetId
        self.valAssetId = valAssetId
    }

    private func createCustomAssetViewModel(for asset: WalletAsset,
                                            balanceData: BalanceData,
                                            locale: Locale) -> AssetViewModelProtocol? {
        let amountFormatter = amountFormatterFactory.createDisplayFormatter(for: asset)

        let decimalBalance = balanceData.balance.decimalValue
        let amount: String

        if let balanceString = amountFormatter.value(for: locale).string(from: decimalBalance as NSNumber) {
            amount = balanceString
        } else {
            amount = balanceData.balance.stringValue
        }

        let name = asset.name.value(for: locale)
        let details: String

        if asset.identifier == valAssetId {
            details = R.string.localizable.assetValFullname()
        } else if let platform = asset.platform?.value(for: locale) {
            details = "\(platform) \(name)"
        } else {
            details = name
        }

        let symbolViewModel: WalletImageViewModelProtocol? = createAssetIconViewModel(for: asset)

        let style = assetCellStyleFactory.createCellStyle(for: asset)

        let detailsFactory = AssetDetailsStatusFactory(completedDetails: details,
                                                       locale: locale)

        let command: WalletCommandProtocol?

        if let factory = commandFactory {
            command = commandDecorator.createAssetDetailsDecorator(with: factory,
                                                                   asset: asset,
                                                                   balanceData: balanceData)
        } else {
            command = nil
        }

        return ConfigurableAssetViewModel(assetId: asset.identifier,
                                          dataProvider: dataProvider,
                                          amount: amount,
                                          symbol: nil,
                                          detailsFactory: detailsFactory,
                                          accessoryDetails: nil,
                                          imageViewModel: symbolViewModel,
                                          style: style,
                                          command: command)
    }
}

extension AccountListViewModelFactory: AccountListViewModelFactoryProtocol {
    func createAssetViewModel(for asset: WalletAsset,
                              balance: BalanceData,
                              commandFactory: WalletCommandFactoryProtocol,
                              locale: Locale) -> WalletViewModelProtocol? {
        if asset.identifier == ethAssetId || asset.identifier == valAssetId {
            return createCustomAssetViewModel(for: asset, balanceData: balance, locale: locale)
        } else {
            return nil
        }
    }

    func createAssetIconViewModel(for asset: WalletAsset) -> WalletImageViewModelProtocol? {
        let symbolViewModel: WalletImageViewModelProtocol?

        if asset.identifier == ethAssetId {
            if let icon = R.image.iconEth() {
                symbolViewModel = WalletStaticImageViewModel(staticImage: icon)
            } else {
                symbolViewModel = nil
            }
        } else {
            if let icon = R.image.iconVal() {
                symbolViewModel = WalletStaticImageViewModel(staticImage: icon)
            } else {
                symbolViewModel = nil
            }
        }
        return symbolViewModel
    }

}
