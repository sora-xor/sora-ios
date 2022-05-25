import Foundation
import CommonWallet

final class TransactionDetailsConfigurator {
    let viewModelFactory: TransactionDetailsViewModelFactory

    init(account: AccountItem,
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         assets: [WalletAsset],
         assetManager: AssetManagerProtocol) {
        viewModelFactory = TransactionDetailsViewModelFactory(account: account,
                                                              assets: assets,
                                                              assetManager: assetManager,
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
