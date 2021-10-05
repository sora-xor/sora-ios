import Foundation
import CommonWallet

class WalletTransferErrorHandler: OperationDefinitionErrorHandling {
    let xorAsset: WalletAsset
    let ethAsset: WalletAsset
    let formatterFactory: NumberFormatterFactoryProtocol
    let commandDecorator: WalletCommandDecoratorFactory
    weak var commandFactory: WalletCommandFactoryProtocol?

    init(xorAsset: WalletAsset,
         ethAsset: WalletAsset,
         formatterFactory: NumberFormatterFactoryProtocol,
         commandDecorator: WalletCommandDecoratorFactory,
         commandFactory: WalletCommandFactoryProtocol?) {
        self.xorAsset = xorAsset
        self.ethAsset = ethAsset
        self.formatterFactory = formatterFactory
        self.commandFactory = commandFactory
        self.commandDecorator = commandDecorator
    }

    func mapError(_ error: Error, locale: Locale) -> OperationDefinitionErrorMapping? {
        if
            let validatorError = error as? TransferValidatingError,
            case .unsufficientFunds(let assetId, let balance) = validatorError {

            if ethAsset.identifier == assetId {
                let formatter = formatterFactory.createTokenFormatter(for: ethAsset).value(for: locale)
                let formattedAmount = formatter.stringFromDecimal(balance) ?? balance.stringWithPointSeparator
                let message = R.string.localizable.transferUnsuffientFundsFormat(ethAsset.name.value(for: locale),
                                                                                 formattedAmount,
                                                                                 preferredLanguages: locale.rLanguages)
                return OperationDefinitionErrorMapping(type: .fee, message: message)
            } else {
                let formatter = formatterFactory.createTokenFormatter(for: xorAsset).value(for: locale)
                let formattedAmount = formatter.stringFromDecimal(balance) ?? balance.stringWithPointSeparator
                let message = R.string.localizable.transferUnsuffientFundsFormat(xorAsset.name.value(for: locale),
                                                                                 formattedAmount,
                                                                                 preferredLanguages: locale.rLanguages)
                return OperationDefinitionErrorMapping(type: .amount, message: message)
            }

        }

        if let bridgeError = error as? WalletNetworkFacadeError,
            case .ethBridgeDisabled  = bridgeError {
            let command = EthBridgeErrorCommand(commandFactory: commandFactory!, locale: locale)
            return OperationDefinitionErrorMapping(type: .receiver,
                                                   message: R.string.localizable.transactionBridgeNotActiveError(
                                                            preferredLanguages: locale.rLanguages)//,
//                                                   command: command
            )
        }

        return nil
    }
}
