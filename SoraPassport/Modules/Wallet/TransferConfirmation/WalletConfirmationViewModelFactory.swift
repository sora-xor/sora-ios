import Foundation
import CommonWallet
import FearlessUtils
import SoraKeystore

final class WalletConfirmationViewModelFactory {
    private let iconGenerator = PolkadotIconGenerator()
    weak var commandFactory: WalletCommandFactoryProtocol?

    let assets: [WalletAsset]
    let assetManager: AssetManagerProtocol
    let amountFormatterFactory: NumberFormatterFactoryProtocol

    init(assets: [WalletAsset], assetManager: AssetManagerProtocol, amountFormatterFactory: NumberFormatterFactoryProtocol) {
        self.assets = assets
        self.assetManager = assetManager
        self.amountFormatterFactory = amountFormatterFactory
    }

    func populateAsset(in viewModelList: inout [WalletFormViewBindingProtocol],
                       payload: ConfirmationPayload,
                       locale: Locale) {
        let headerTitle = R.string.localizable.transactionToken(preferredLanguages: locale.rLanguages)

        guard let asset = self.assets.first(where: {$0.identifier == payload.transferInfo.asset}),
            let context = payload.transferInfo.context else {
            return
        }
        let symbolViewModel: WalletImageViewModelProtocol?

        if  let assetInfo = assetManager.assetInfo(for: asset.identifier),
            let iconString = assetInfo.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            symbolViewModel = nil
        }

        let balanceData = BalanceContext(context: context)
        let title: String =  asset.name.value(for: locale)
        let subtitle: String = asset.identifier

        let formatter = amountFormatterFactory.createDisplayFormatter(for: asset)

        let details = formatter.value(for: locale).stringFromDecimal(balanceData.available) ?? ""

        let selectedState = SelectedAssetState(isSelecting: false, canSelect: false)

        let tokenViewModel = WalletTokenViewModel(
            state: selectedState,
            header: headerTitle,
            title: title,
            subtitle: subtitle,
            details: details,
            icon: nil,
            iconViewModel: symbolViewModel
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: tokenViewModel, borderType: [.bottom]))
    }

    func populateReceiver(in viewModelList: inout [WalletFormViewBindingProtocol],
                          payload: ConfirmationPayload,
                          locale: Locale) {

        let name = payload.receiverName
        let title = R.string.localizable.transactionReceiverTitle(preferredLanguages: locale.rLanguages)
        let icon = try? iconGenerator.generateFromAddress(payload.receiverName)
                .imageWithFillColor(.white,
                                    size: CGSize(width: 24.0, height: 24.0),
                                    contentScale: UIScreen.main.scale)
        let command = SendToContactCommand(nextAction: {
            UIPasteboard.general.string = name
            let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages))
            try? self.commandFactory?.preparePresentationCommand(for: success).execute()
        })

        let viewModel = WalletSoraReceiverViewModel(text: name, icon: icon, title: title, command: command)

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
    }

    func populateSendingAmount(in viewModelList: inout [WalletFormViewBindingProtocol],
                               payload: ConfirmationPayload,
                               locale: Locale) {
        guard let asset = assets.first(where: { $0.identifier == payload.transferInfo.asset }) else {
            return
        }

        let formatter = amountFormatterFactory.createDisplayFormatter(for: asset)

        let decimalAmount = payload.transferInfo.amount.decimalValue

        guard let amount = formatter.value(for: locale).stringFromDecimal(decimalAmount) else {
            return
        }

        let title = R.string.localizable.transactionAmountTitle(preferredLanguages: locale.rLanguages)
        let viewModel = WalletFormSpentAmountModel(title: title,
                                                   amount: amount)
        viewModelList.append(viewModel)
    }

    func populateMainFeeAmount(in viewModelList: inout [WalletFormViewBindingProtocol],
                               payload: ConfirmationPayload,
                               locale: Locale) {
        guard let asset = assets.first(where: { $0.isFeeAsset }) else {
            return
        }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

        for fee in payload.transferInfo.fees
        where fee.feeDescription.identifier == asset.identifier {

            let decimalAmount = fee.value.decimalValue

            guard let amount = formatter.stringFromDecimal(decimalAmount) else {
                return
            }

            let title = R.string.localizable.transactionSoranetFeeTitle(preferredLanguages: locale.rLanguages)

            let viewModel = FeeViewModel(title: title, details: amount, isLoading: false, allowsEditing: false)

            viewModelList.append(viewModel)
        }
    }
}

extension WalletConfirmationViewModelFactory: TransferConfirmationViewModelFactoryOverriding {
    func createViewModelsFromPayload(_ payload: ConfirmationPayload,
                                     locale: Locale) -> [WalletFormViewBindingProtocol]? {
        var viewModelList: [WalletFormViewBindingProtocol] = []

        populateAsset(in: &viewModelList, payload: payload, locale: locale)
        populateReceiver(in: &viewModelList, payload: payload, locale: locale)
        populateSendingAmount(in: &viewModelList, payload: payload, locale: locale)
        populateMainFeeAmount(in: &viewModelList, payload: payload, locale: locale)

        return viewModelList
    }

    func createAccessoryViewModelFromPayload(_ payload: ConfirmationPayload,
                                             locale: Locale) -> AccessoryViewModelProtocol? {
        AccessoryViewModel(title: "",
                           action: R.string.localizable.transactionConfirm(preferredLanguages: locale.rLanguages))
    }
}
