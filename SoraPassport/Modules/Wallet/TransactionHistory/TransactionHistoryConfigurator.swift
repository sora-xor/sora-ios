/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import SoraFoundation

final class TransactionHistoryConfigurator {
    private var historyViewModelFactory: WalletHistoryViewModelFactory

    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            historyViewModelFactory.commandFactory
        }

        set {
            historyViewModelFactory.commandFactory = newValue
        }
    }

    init(amountFormatterFactory: NumberFormatterFactoryProtocol,
         assets: [WalletAsset],
         accountId: String,
         ethereumAddress: String) {

        let color = UIColor(red: 0.379, green: 0.379, blue: 0.379, alpha: 1)
        let textStyle = WalletTextStyle(font: R.font.soraRc0040417Regular(size: 12)!,
                                        color: color)

        let stroke = WalletStrokeStyle(color: color, lineWidth: 1.0)
        let generatingIconStyle = WalletNameIconStyle(background: .white,
                                                      title: textStyle,
                                                      radius: 15.0,
                                                      stroke: stroke)

        historyViewModelFactory =
            WalletHistoryViewModelFactory(amountFormatterFactory: amountFormatterFactory,
                                          dateFormatter: DateFormatter.history,
                                          nameIconStyle: generatingIconStyle,
                                          assets: assets,
                                          accountId: accountId,
                                          ethereumAddress: ethereumAddress)
    }

    func configure(using builder: HistoryModuleBuilderProtocol) {
        builder
            .with(cellNib: UINib(resource: R.nib.walletHistoryCell),
                  for: R.reuseIdentifier.walletHistoryCellId.identifier)
            .with(itemViewModelFactory: historyViewModelFactory)
            .with(emptyStateDataSource: WalletEmptyStateDataSource.history)
            .with(supportsFilter: false)
            .with(includesFeeInAmount: false)
            .with(historyViewStyle: HistoryViewStyle.sora)
            .with(transactionCellStyle: TransactionCellStyle.sora)
            .with(transactionHeaderStyle: TransactionHeaderStyle.sora)
    }
}
