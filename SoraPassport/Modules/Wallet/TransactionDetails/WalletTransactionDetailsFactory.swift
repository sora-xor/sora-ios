import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

final class TransactionDetailsViewModelFactory {
    let account: AccountItem
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let assets: [WalletAsset]

    let iconGenerator: PolkadotIconGenerator = PolkadotIconGenerator()

    init(account: AccountItem,
         assets: [WalletAsset],
         dateFormatter: LocalizableResource<DateFormatter>,
         amountFormatterFactory: NumberFormatterFactoryProtocol) {
        self.account = account
        self.assets = assets
        self.dateFormatter = dateFormatter
        self.amountFormatterFactory = amountFormatterFactory
    }

    private func populateStatus(into viewModelList: inout [WalletFormViewBindingProtocol],
                                data: AssetTransactionData,
                                locale: Locale) {
        let viewModel: SoraTransactionStatusViewModel

        let title = R.string.localizable
            .walletTxDetailsStatus(preferredLanguages: locale.rLanguages)

        switch data.status {
        case .commited:
            let details = R.string.localizable
                .statusSuccess(preferredLanguages: locale.rLanguages)
            viewModel = SoraTransactionStatusViewModel(title: title,
                                                      titleIcon: nil,
                                                      details: details,
                                                      detailsIcon: R.image.iconTxStatusSuccess())
        case .pending:
            let details = R.string.localizable
                .walletTxDetailsPending(preferredLanguages: locale.rLanguages)
            viewModel = SoraTransactionStatusViewModel(title: title,
                                                      titleIcon: nil,
                                                      details: details,
                                                      detailsIcon: R.image.iconTxPending())
        case .rejected:
            let details = R.string.localizable
                .statusError(preferredLanguages: locale.rLanguages)
            viewModel = SoraTransactionStatusViewModel(title: title,
                                                      titleIcon: nil,
                                                      details: details,
                                                      detailsIcon: R.image.iconTxStatusError())
        }

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateAmount(into viewModelList: inout [WalletFormViewBindingProtocol],
                                data: AssetTransactionData,
                                locale: Locale) {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            return
        }

        let amount = data.amount.decimalValue

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset)

        guard let displayAmount = formatter.value(for: locale).stringFromDecimal(amount) else {
            return
        }

        var title = R.string.localizable
            .transactionAmountTitle(preferredLanguages: locale.rLanguages)
        switch data.direction {
        case .incoming :
            title = R.string.localizable
                .commonReceived(preferredLanguages: locale.rLanguages)
        case .outgoing :
            title = R.string.localizable
                .commonSent(preferredLanguages: locale.rLanguages)
        }

        let viewModel = SoraTransactionAmountViewModel(title: title,
                                                      details: displayAmount)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateFeeAmount(in viewModelList: inout [WalletFormViewBindingProtocol],
                                   data: AssetTransactionData,
                                   locale: Locale) {
        let asset = assets.first { $0.isFeeAsset }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

        for fee in data.fees {

            guard let amount = formatter.stringFromDecimal(fee.amount.decimalValue) else {
                continue
            }

            let title = R.string.localizable.transactionSoranetFeeTitle(preferredLanguages: locale.rLanguages)

            let viewModel = FeeViewModel(title: title,
                                         details: amount,
                                         isLoading: false,
                                         allowsEditing: false)

            let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
            viewModelList.append(separator)
        }
    }

    private func populateTransactionId(in viewModelList: inout [WalletFormViewBindingProtocol],
                                       data: AssetTransactionData,
                                       chain: Chain,
                                       commandFactory: WalletCommandFactoryProtocol,
                                       locale: Locale) {
        let title = R.string.localizable
            .transactionHash(preferredLanguages: locale.rLanguages)

        let command = SendToContactCommand(nextAction: {
            UIPasteboard.general.string =  data.transactionId
            let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages))
            try? commandFactory.preparePresentationCommand(for: success).execute()
        })

        let viewModel = WalletSoraReceiverViewModel(text: data.transactionId, icon: nil, title: title, command: command)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateSender(in viewModelList: inout [WalletFormViewBindingProtocol],
                                address: String,
                                chain: Chain,
                                commandFactory: WalletCommandFactoryProtocol,
                                locale: Locale) {
        let title = R.string.localizable
            .commonFrom(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(in: &viewModelList,
                              title: title,
                              address: address,
                              chain: chain,
                              commandFactory: commandFactory,
                              locale: locale)
    }

    private func populateReceiver(in viewModelList: inout [WalletFormViewBindingProtocol],
                                  address: String,
                                  chain: Chain,
                                  commandFactory: WalletCommandFactoryProtocol,
                                  locale: Locale) {
        let title = R.string.localizable
            .transactionReceiverTitle(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(in: &viewModelList,
                              title: title,
                              address: address,
                              chain: chain,
                              commandFactory: commandFactory,
                              locale: locale)
    }

    private func populatePeerViewModel(in viewModelList: inout [WalletFormViewBindingProtocol],
                                       title: String,
                                       address: String,
                                       chain: Chain,
                                       commandFactory: WalletCommandFactoryProtocol,
                                       locale: Locale) {

        let command = SendToContactCommand(nextAction: {
            UIPasteboard.general.string = address
            let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages))
            try? commandFactory.preparePresentationCommand(for: success).execute()
        })

        let viewModel = WalletSoraReceiverViewModel(text: address, icon: nil, title: title, command: command)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    func populateHeader (into viewModelList: inout [WalletFormViewBindingProtocol],
                         data: AssetTransactionData,
                         locale: Locale) {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            return
        }

        let amount = data.amount.decimalValue

        let formatter = (amountFormatterFactory as? AmountFormatterFactory)!.createShortFormatter(for: asset)

        guard var displayAmount = formatter.value(for: locale).stringFromDecimal(amount) else {
            return
        }

        switch data.direction {
        case .incoming :
            displayAmount = "\(String.amountIncrease) \(displayAmount)"
        case .outgoing :
            displayAmount = "\(String.amountDecrease) \(displayAmount)"
        }

        let transactionDate = Date(timeIntervalSince1970: TimeInterval(data.timestamp))

        let timeDetails = dateFormatter.value(for: locale).string(from: transactionDate)

        let viewModel = SoraTransactionHeaderViewModel(title: displayAmount, details: timeDetails, direction: data.direction)

        viewModelList.append(viewModel)

    }
}

extension TransactionDetailsViewModelFactory: WalletTransactionDetailsFactoryOverriding {
    func createViewModelsFromTransaction(data: AssetTransactionData,
                                         commandFactory: WalletCommandFactoryProtocol,
                                         locale: Locale) -> [WalletFormViewBindingProtocol]? {

        let chain: Chain = .sora
        var viewModels: [WalletFormViewBindingProtocol] = []
        populateHeader(into: &viewModels, data: data, locale: locale)
        populateStatus(into: &viewModels, data: data, locale: locale)
        populateTransactionId(in: &viewModels,
                              data: data,
                              chain: chain,
                              commandFactory: commandFactory,
                              locale: locale)

        guard let type = TransactionType(rawValue: data.type), let peerAddress = data.peerName else {
            return viewModels
        }

        let name = account.address

        if type == .incoming {
            populateSender(in: &viewModels,
                           address: peerAddress,
                           chain: chain,
                           commandFactory: commandFactory,
                           locale: locale)
            populateReceiver(in: &viewModels,
                             address: name,
                             chain: chain,
                             commandFactory: commandFactory,
                             locale: locale)
        } else {
            populateSender(in: &viewModels,
                           address: name,
                           chain: chain,
                           commandFactory: commandFactory,
                           locale: locale)
            populateReceiver(in: &viewModels,
                             address: peerAddress,
                             chain: chain,
                             commandFactory: commandFactory,
                             locale: locale)
        }

        populateAmount(into: &viewModels, data: data, locale: locale)

        if type == .outgoing {
            populateFeeAmount(in: &viewModels, data: data, locale: locale)
        }

        return viewModels
    }

    func createAccessoryViewModelFromTransaction(data: AssetTransactionData,
                                                 commandFactory: WalletCommandFactoryProtocol,
                                                 locale: Locale) -> AccessoryViewModelProtocol? {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            return nil
        }

        let receiverInfo = ReceiveInfo(accountId: data.peerId,
                                       assetId: asset.identifier,
                                       amount: data.amount,
                                       details: nil)

        let transferPayload = TransferPayload(receiveInfo: receiverInfo,
                                              receiverName: data.peerName ?? "")
        let command = commandFactory.prepareTransfer(with: transferPayload)
        command.presentationStyle = .push(hidesBottomBar: true)

        let action: String

        if data.status == .rejected {
            action = R.string.localizable.commonRetry(preferredLanguages: locale.rLanguages)
        } else {
            switch data.direction {
            case .incoming :
                action = R.string.localizable
                        .walletTxDetailsSendBack(preferredLanguages: locale.rLanguages)
            case .outgoing :
                action = R.string.localizable
                        .walletTxDetailsSendAgain(preferredLanguages: locale.rLanguages)
            }

        }
        return AccessoryViewModel(title: "",
                           action: action)

    }
}
