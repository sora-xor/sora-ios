import Foundation
import CommonWallet
import RobinHood
import SoraFoundation
import SoraKeystore

final class AccountListViewModelFactory {
    let commandDecorator: WalletCommandDecoratorFactoryProtocol
//    weak var commandFactory: WalletCommandFactoryProtocol?

    let assetCellStyleFactory: AssetCellStyleFactoryProtocol
    let amountFormatterFactory: AmountFormatterFactoryProtocol
    let assetManager: AssetManagerProtocol
//    let priceAsset: WalletAsset

    init(address: String,
         chain: Chain,
         assetCellStyleFactory: AssetCellStyleFactoryProtocol,
         assetManager: AssetManagerProtocol,
         commandDecorator: WalletCommandDecoratorFactoryProtocol,
         amountFormatterFactory: AmountFormatterFactoryProtocol) {
        self.assetCellStyleFactory = assetCellStyleFactory
        self.amountFormatterFactory = amountFormatterFactory
        self.commandDecorator = commandDecorator
        self.assetManager = assetManager
    }

    var visibleAssets: UInt {
        assetManager.visibleCount()
    }

    private func createCustomAssetViewModel(for asset: WalletAsset,
                                            balanceData: BalanceData,
                                            commandFactory: WalletCommandFactoryProtocol,
                                            locale: Locale) -> AssetViewModelProtocol? {
        let amountFormatter = amountFormatterFactory.createDisplayFormatter(for: asset, maxPrecision: 8)

        guard let assetInfo = assetManager.assetInfo(for: asset.identifier) else {return nil}

        let decimalBalance = balanceData.balance.decimalValue
        let amount: String

        var toggleImage = R.image.iconVisibleOff()

        if asset.isFeeAsset && !assetInfo.visible {
            amount = ""
            toggleImage =  R.image.iconVisibleOn()
        } else if let balanceString = amountFormatter.value(for: locale).stringFromDecimal(decimalBalance) {
            amount = balanceString
        } else {
            amount = balanceData.balance.stringValue
        }

        let name = asset.name.value(for: locale)
        let details: String

        if let platform = asset.platform?.value(for: locale) {
            details = platform
        } else {
            details = name
        }

        let symbolViewModel: WalletImageViewModelProtocol? = createAssetIconViewModel(for: asset)

        let style = assetCellStyleFactory.createCellStyle(for: asset)

        let assetDetailsCommand = commandDecorator.createAssetDetailsDecorator(with: commandFactory, asset: asset, balanceData: nil)

        let toggleCommand: WalletCommandDecoratorProtocol?

        if let factory = commandDecorator as? WalletCommandDecoratorFactory {
            toggleCommand = factory.createVisibilityToggleCommand(with: commandFactory, for: asset)
        } else {
            toggleCommand = nil
        }

        return ConfigurableAssetViewModel(assetId: asset.identifier,
                                          amount: amount,
                                          symbol: nil,
                                          details: details,
                                          accessoryDetails: name,
                                          imageViewModel: symbolViewModel,
                                          style: style,
                                          command: assetDetailsCommand,
                                          toggleCommand: toggleCommand,
                                          toggleIcon: toggleImage)
    }
}

extension AccountListViewModelFactory: AccountListViewModelFactoryProtocol {

    func createAssetViewModel(for asset: WalletAsset,
                              balance: BalanceData,
                              commandFactory: WalletCommandFactoryProtocol,
                              locale: Locale) -> WalletViewModelProtocol? {
        let locale = LocalizationManager.shared.selectedLocale
        return createCustomAssetViewModel(for: asset, balanceData: balance, commandFactory: commandFactory, locale: locale)
    }

    func createActionsViewModel(for assetId: String?,
                                commandFactory: WalletCommandFactoryProtocol,
                                locale: Locale) -> WalletViewModelProtocol? {
        return EmptyActionsViewModel()
    }

    func createShowMoreViewModel(for delegate: ShowMoreViewModelDelegate?,
                                 locale: Locale) -> WalletViewModelProtocol? {
        return EmptyShowMoreViewModel(delegate: delegate)
    }

    func createAssetIconViewModel(for asset: WalletAsset) -> WalletImageViewModelProtocol? {
        let symbolViewModel: WalletImageViewModelProtocol?

        if  let assetInfo = assetManager.assetInfo(for: asset.identifier),
            let iconString = assetInfo.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            symbolViewModel = nil
        }
        return symbolViewModel
    }
}

class EmptyActionsViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String = "co.jp.capital.asset.actions.cell.identifier"

    var itemHeight: CGFloat = 0

    var command: WalletCommandProtocol?
}

class EmptyShowMoreViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String = "co.jp.capital.asset.more.cell.identifier"

    var itemHeight: CGFloat = 0

    var command: WalletCommandProtocol?

    weak var delegate: ShowMoreViewModelDelegate?
    let expanded: Bool = true

    init(delegate: ShowMoreViewModelDelegate?) {
        self.delegate = delegate
    }
}
