import Foundation
import CommonWallet

final class WalletTransactionDetailsConfigurator {
    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            viewModelFactory.commandFactory
        }

        set {
            viewModelFactory.commandFactory = newValue
        }
    }

    private let viewModelFactory: WalletTransactionDetailsFactory

    init(feeDisplayFactory: FeeDisplaySettingsFactoryProtocol,
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         assets: [WalletAsset],
         accountId: String,
         ethereumAddress: String,
         soranetExplorerTemplate: String,
         ethereumExplorerTemplate: String) {

        let color = UIColor(red: 0.379, green: 0.379, blue: 0.379, alpha: 1)
        let textStyle = WalletTextStyle(font: R.font.soraRc0040417Regular(size: 12)!,
                                        color: color)

        let stroke = WalletStrokeStyle(color: color, lineWidth: 1.0)
        let nameIconStyle = WalletNameIconStyle(background: .white,
                                                title: textStyle,
                                                radius: 15.0,
                                                stroke: stroke)

        viewModelFactory = WalletTransactionDetailsFactory(feeDisplayFactory: feeDisplayFactory,
                                                           amountFormatterFactory: amountFormatterFactory,
                                                           dateFormatter: DateFormatter.transactionDetails,
                                                           assets: assets,
                                                           accountId: accountId,
                                                           ethereumAddress: ethereumAddress,
                                                           nameIconStyle: nameIconStyle,
                                                           soranetExplorerTemplate: soranetExplorerTemplate,
                                                           ethereumExplorerTemplate: ethereumExplorerTemplate)
    }

    func configure(using builder: TransactionDetailsModuleBuilderProtocol) {
        let binder = WalletTransactionDetailsViewBinder()
        let definitionFactory = WalletTxDetailsDefinitionFactory()

        builder
            .with(viewBinder: binder)
            .with(definitionFactory: definitionFactory)
            .with(viewModelFactory: viewModelFactory)
    }
}
