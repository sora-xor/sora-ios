import Foundation
import CommonWallet
import SoraFoundation

final class TransactionHistoryConfigurator {
    private lazy var transactionCellStyle: TransactionCellStyleProtocol = {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1),
                                    color: R.color.baseContentPrimary()!)
        let amount = WalletTextStyle(font: UIFont.styled(for: .paragraph1),
                                     color: R.color.baseContentPrimary()!)
        let style = WalletTransactionStatusStyle(icon: nil,
                                                 color: R.color.baseContentPrimary()!)
        let container = WalletTransactionStatusStyleContainer(approved: style,
                                                              pending: style,
                                                              rejected: style)
        return TransactionCellStyle(backgroundColor: .clear,
                                    title: title,
                                    amount: amount,
                                    statusStyleContainer: container,
                                    increaseAmountIcon: nil,
                                    decreaseAmountIcon: nil,
                                    separatorColor: .clear)
    }()

    private lazy var headerStyle: TransactionHeaderStyleProtocol = {
        let title = WalletTextStyle(font: UIFont.styled(for: .uppercase1),
                                    color: R.color.baseContentPrimary()!)
        return TransactionHeaderStyle(background: .clear,
                                      title: title,
                                      separatorColor: .clear,
                                      upppercased: true)
    }()

    let viewModelFactory: TransactionHistoryViewModelFactory

    init(amountFormatterFactory: AmountFormatterFactoryProtocol, assets: [WalletAsset], assetManager: AssetManagerProtocol) {
        viewModelFactory = TransactionHistoryViewModelFactory(amountFormatterFactory: amountFormatterFactory,
                                                              dateFormatter: DateFormatter.history,
                                                              assets: assets,
                                                              assetManager: assetManager)
    }

    func configure(builder: HistoryModuleBuilderProtocol) {
        let title = LocalizableResource { locale in
            return R.string.localizable
                .historyTitle(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
        }

        builder
            .with(itemViewModelFactory: viewModelFactory)
            .with(emptyStateDataSource: WalletEmptyStateDataSource.history)
            .with(historyViewStyle: HistoryViewStyle.sora)
            .with(transactionCellStyle: TransactionCellStyle.sora)
            .with(cellNib: UINib(resource: R.nib.walletHistoryCell),
                  for: R.reuseIdentifier.walletHistoryCellId.identifier)
            .with(cellClass: LiquidityHistoryCell.self, for: HistoryConstants.liquidityHistoryCellId)
            .with(transactionHeaderStyle: TransactionHeaderStyle.sora)
            .with(supportsFilter: false)
            .with(includesFeeInAmount: false)
            .with(localizableTitle: title)
//            .with(viewFactoryOverriding: WalletHistoryViewFactoryOverriding())
    }
}
