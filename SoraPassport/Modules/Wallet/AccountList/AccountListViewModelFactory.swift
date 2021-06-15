import Foundation
import CommonWallet
import RobinHood
import SoraFoundation

final class AccountListViewModelFactory {
    let commandDecorator: WalletCommandDecoratorFactoryProtocol
//    weak var commandFactory: WalletCommandFactoryProtocol?

    let assetCellStyleFactory: AssetCellStyleFactoryProtocol
    let amountFormatterFactory: NumberFormatterFactoryProtocol
//    let priceAsset: WalletAsset
//    let accountCommandFactory: WalletSelectAccountCommandFactoryProtocol

    init(address: String,
         chain: Chain,
         assetCellStyleFactory: AssetCellStyleFactoryProtocol,
         commandDecorator: WalletCommandDecoratorFactoryProtocol,
         amountFormatterFactory: NumberFormatterFactoryProtocol) {
        self.assetCellStyleFactory = assetCellStyleFactory
        self.amountFormatterFactory = amountFormatterFactory
        self.commandDecorator = commandDecorator
    }

    private func createCustomAssetViewModel(for asset: WalletAsset,
                                            balanceData: BalanceData,
                                            commandFactory: WalletCommandFactoryProtocol,
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
            details = platform
        } else {
            details = name
        }

        let symbolViewModel: WalletImageViewModelProtocol? = createAssetIconViewModel(for: asset)

        let style = assetCellStyleFactory.createCellStyle(for: asset)

        let assetDetailsCommand = commandDecorator.createAssetDetailsDecorator(with: commandFactory, asset: asset, balanceData: nil)

        return ConfigurableAssetViewModel(assetId: asset.identifier,
                                          amount: amount,
                                          symbol: nil,
                                          details: details,
                                          accessoryDetails: name,
                                          imageViewModel: symbolViewModel,
                                          style: style,
                                          command: assetDetailsCommand)
    }
}

extension AccountListViewModelFactory: AccountListViewModelFactoryProtocol {
    struct AccountModuleConstants {
        static let actionsCellIdentifier: String = "co.jp.capital.asset.actions.cell.identifier"
        static let actionsCellHeight: CGFloat = 100.0
    }

    func createAssetViewModel(for asset: WalletAsset,
                              balance: BalanceData,
                              commandFactory: WalletCommandFactoryProtocol,
                              locale: Locale) -> WalletViewModelProtocol? {
            return createCustomAssetViewModel(for: asset, balanceData: balance, commandFactory: commandFactory, locale: locale)
    }

    func createActionsViewModel(for assetId: String?,
                                commandFactory: WalletCommandFactoryProtocol,
                                locale: Locale) -> WalletViewModelProtocol? {

        let style = WalletTextStyle(font: UIFont.styled(for: .paragraph2), color: R.color.baseContentPrimary()!)
        let actionsStyle = ActionsCellStyle.init(sendText: style, receiveText: style)

        var sendCommand: WalletCommandProtocol = commandFactory.prepareSendCommand(for: assetId)

        if let sendDecorator = commandDecorator.createSendCommandDecorator(with: commandFactory) {
            sendDecorator.undelyingCommand = sendCommand
            sendCommand = sendDecorator
        }

        let sendViewModel = ActionViewModel(title: R.string.localizable.commonSend(preferredLanguages: locale.rLanguages),
                                            style: actionsStyle.sendText,
                                            command: sendCommand)

        var receiveCommand: WalletCommandProtocol = commandFactory.prepareReceiveCommand(for: assetId)

        if let receiveDecorator = commandDecorator.createReceiveCommandDecorator(with: commandFactory) {
            receiveDecorator.undelyingCommand = receiveCommand
            receiveCommand = receiveDecorator
        }

        let receiveViewModel = ActionViewModel(title: R.string.localizable.commonReceive(preferredLanguages: locale.rLanguages),
                                               style: actionsStyle.receiveText,
                                               command: receiveCommand)

        return ActionsViewModel(cellReuseIdentifier: AccountModuleConstants.actionsCellIdentifier,
                                itemHeight: AccountModuleConstants.actionsCellHeight,
                                sendViewModel: sendViewModel,
                                receiveViewModel: receiveViewModel)
    }

    func createAssetIconViewModel(for asset: WalletAsset) -> WalletImageViewModelProtocol? {
        let symbolViewModel: WalletImageViewModelProtocol?

        if let icon = WalletAssetId(rawValue: asset.identifier)?.assetIcon {
            symbolViewModel = WalletStaticImageViewModel(staticImage: icon)
        } else {
            symbolViewModel = nil
        }

        return symbolViewModel
    }
}

final class ActionViewModel: ActionViewModelProtocol {
    var title: String
    var style: WalletTextStyleProtocol
    var command: WalletCommandProtocol

    init(title: String, style: WalletTextStyleProtocol, command: WalletCommandProtocol) {
        self.title = title
        self.style = style
        self.command = command
    }
}

final class ActionsViewModel: ActionsViewModelProtocol {
    var cellReuseIdentifier: String
    var itemHeight: CGFloat

    var command: WalletCommandProtocol? { return nil }

    var send: ActionViewModelProtocol
    var receive: ActionViewModelProtocol

    init(cellReuseIdentifier: String,
         itemHeight: CGFloat,
         sendViewModel: ActionViewModelProtocol,
         receiveViewModel: ActionViewModelProtocol) {
        self.cellReuseIdentifier = cellReuseIdentifier
        self.itemHeight = itemHeight
        self.send = sendViewModel
        self.receive = receiveViewModel
    }

}
