/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

final class TransactionDetailsConfigurator {
    let viewModelFactory: TransactionDetailsViewModelFactory

    init(account: AccountItem,
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         assets: [WalletAsset]) {
        viewModelFactory = TransactionDetailsViewModelFactory(account: account,
                                                              assets: assets,
                                                              dateFormatter: DateFormatter.transactionDetails,
                                                              amountFormatterFactory: amountFormatterFactory)
    }

    func configure(builder: TransactionDetailsModuleBuilderProtocol) {
        builder
            .with(viewModelFactory: viewModelFactory)
            .with(viewBinder: WalletTransactionDetailsViewBinder())
            .with(definitionFactory: WalletTxDetailsDefinitionFactory())
            .with(accessoryViewFactory: WalletTransactionDetailsAccessoryFactory.self)
    }
}
