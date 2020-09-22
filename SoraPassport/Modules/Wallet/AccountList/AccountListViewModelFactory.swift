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

    weak var commandFactory: WalletCommandFactoryProtocol?

    init(dataProvider: StreamableProvider<EthereumInit>,
         commandDecorator: WalletCommandDecoratorFactoryProtocol,
         assetCellStyleFactory: AssetCellStyleFactoryProtocol,
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         ethAssetId: String) {
        self.dataProvider = dataProvider
        self.commandDecorator = commandDecorator
        self.assetCellStyleFactory = assetCellStyleFactory
        self.amountFormatterFactory = amountFormatterFactory
        self.ethAssetId = ethAssetId
    }

    private func createEthAssetViewModel(for asset: WalletAsset,
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

        if let platform = asset.platform?.value(for: locale) {
            details = "\(platform) \(name)"
        } else {
            details = name
        }

        let symbolViewModel: WalletImageViewModelProtocol?

        if let icon = R.image.iconEth() {
            symbolViewModel = WalletStaticImageViewModel(staticImage: icon)
        } else {
            symbolViewModel = nil
        }

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
                              locale: Locale) -> AssetViewModelProtocol? {
        if asset.identifier == ethAssetId {
            return createEthAssetViewModel(for: asset, balanceData: balance, locale: locale)
        } else {
            return nil
        }
    }
}
