import CommonWallet
import FearlessUtils
import Foundation
import SoraFoundation

final class TransactionDetailsViewModelFactory {
    let account: AccountItem
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let assets: [WalletAsset]
    let assetManager: AssetManagerProtocol

    let iconGenerator: PolkadotIconGenerator = PolkadotIconGenerator()

    init(
        account: AccountItem,
        assets: [WalletAsset],
        assetManager: AssetManagerProtocol,
        dateFormatter: LocalizableResource<DateFormatter>,
        amountFormatterFactory: NumberFormatterFactoryProtocol
    ) {
        self.account = account
        self.assets = assets
        self.assetManager = assetManager
        self.dateFormatter = dateFormatter
        self.amountFormatterFactory = amountFormatterFactory
    }

    private func populateStatus(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let viewModel: SoraTransactionStatusViewModel

        let title = R.string.localizable.walletTxDetailsStatus(preferredLanguages: locale.rLanguages)

        switch data.status {
        case .commited:
            let details = R.string.localizable
                .statusSuccess(preferredLanguages: locale.rLanguages)
            viewModel = SoraTransactionStatusViewModel(
                title: title,
                titleIcon: nil,
                details: details,
                detailsIcon: R.image.iconTxStatusSuccess()
            )
        case .pending:
            let details = R.string.localizable
                .walletTxDetailsPending(preferredLanguages: locale.rLanguages)
            viewModel = SoraTransactionStatusViewModel(
                title: title,
                titleIcon: nil,
                details: details,
                detailsIcon: R.image.iconTxPending()
            )
        case .rejected:
            let details = R.string.localizable
                .statusError(preferredLanguages: locale.rLanguages)
            viewModel = SoraTransactionStatusViewModel(
                title: title,
                titleIcon: nil,
                details: details,
                detailsIcon: R.image.iconTxStatusError()
            )
        }

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateAmount(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
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
        switch data.transactionType {
        case .incoming:
            title = R.string.localizable
                .commonReceived(preferredLanguages: locale.rLanguages)
        case .outgoing:
            title = R.string.localizable
                .commonSent(preferredLanguages: locale.rLanguages)
        case .reward, .slash, .swap, .extrinsic, .liquidityRemoval, .liquidityAdd:
            _ = title
        }

        let viewModel = SoraTransactionAmountViewModel(title: title,
                                                       details: displayAmount)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateFeeAmount(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let asset = assets.first { $0.isFeeAsset }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

        for fee in data.fees {
            guard let amount = formatter.stringFromDecimal(fee.amount.decimalValue) else {
                continue
            }

            let title = fee.context == nil ?
                R.string.localizable.transactionSoranetFeeTitle(preferredLanguages: locale.rLanguages) :
                R.string.localizable.polkaswapLiqudityFee(preferredLanguages: locale.rLanguages)

            let viewModel = WalletNewFormDetailsViewModel(title: title, titleIcon: nil, details: amount, detailsIcon: nil)

            let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
            viewModelList.append(separator)
        }
    }

    private func populateTransactionId(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable
            .transactionHash(preferredLanguages: locale.rLanguages)

        let command = SendToContactCommand(nextAction: {
            UIPasteboard.general.string = data.transactionId
            let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages))
            try? commandFactory.preparePresentationCommand(for: success).execute()
        })

        let viewModel = WalletSoraReceiverViewModel(text: data.transactionId, icon: nil, title: title, command: command)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateSender(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        address: String,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable.transactionSender(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(
            in: &viewModelList,
            title: title,
            address: address,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )
    }

    private func populateReceiver(in viewModelList: inout [WalletFormViewBindingProtocol],
                                  address: String,
                                  chain: Chain,
                                  commandFactory: WalletCommandFactoryProtocol,
                                  locale: Locale) {
        let title = R.string.localizable
            .transactionRecipient(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(in: &viewModelList,
                              title: title,
                              address: address,
                              chain: chain,
                              commandFactory: commandFactory,
                              locale: locale)
    }

    private func populateAccount(in viewModelList: inout [WalletFormViewBindingProtocol],
                                 address: String,
                                 chain: Chain,
                                 commandFactory: WalletCommandFactoryProtocol,
                                 locale: Locale) {
        let title = R.string.localizable
            .commonAccount(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(in: &viewModelList,
                              title: title,
                              address: address,
                              chain: chain,
                              commandFactory: commandFactory,
                              locale: locale)
    }

    private func populatePeerViewModel(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        title: String,
        address: String,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let command = SendToContactCommand(nextAction: {
            UIPasteboard.general.string = address
            let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages))
            try? commandFactory.preparePresentationCommand(for: success).execute()
        })

        let viewModel = WalletSoraReceiverViewModel(text: address, icon: nil, title: title, command: command)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateHeader(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            return
        }

        let amount = data.amount.decimalValue

        let formatter = (amountFormatterFactory as? AmountFormatterFactory)!.createShortFormatter(for: asset)

        guard var displayAmount = formatter.value(for: locale).stringFromDecimal(amount) else {
            return
        }

        switch data.transactionType {
        case .incoming:
            displayAmount = "\(String.amountIncrease) \(displayAmount)"
        case .outgoing:
            displayAmount = "\(String.amountDecrease) \(displayAmount)"
        case .liquidityRemoval:
            displayAmount = "\(String.amountIncrease) \(displayAmount)"
        case .liquidityAdd:
            displayAmount = "\(String.amountDecrease) \(displayAmount)"
        case .reward, .slash, .swap, .extrinsic:
            _ = displayAmount
        }

        let title = "\(asset.symbol)"
        let subtitle = asset.identifier

        let symbolViewModel: WalletImageViewModelProtocol?
        if let assetInfo = assetManager.assetInfo(for: asset.identifier),
           let iconString = assetInfo.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            symbolViewModel = nil
        }

        let viewModel = WalletTokenViewModel(
            state: .init(isSelecting: true, canSelect: true),
            header: asset.platform?.value(for: locale) ?? "",
            title: title,
            subtitle: subtitle,
            details: displayAmount,
            icon: nil,
            iconViewModel: symbolViewModel
        )

        viewModelList.append(viewModel)
    }

    private func populatePeerHeader(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        guard let asset = assets.first(where: { $0.identifier == data.peerId }) else {
            return
        }

        let amount = Decimal(string: data.details) ?? .zero

        let formatter = (amountFormatterFactory as? AmountFormatterFactory)!.createShortFormatter(for: asset)

        guard var displayAmount = formatter.value(for: locale).stringFromDecimal(amount) else {
            return
        }

        switch data.transactionType {
        case .incoming:
            displayAmount = "\(String.amountIncrease) \(displayAmount)"
        case .outgoing:
            displayAmount = "\(String.amountDecrease) \(displayAmount)"
        case .liquidityRemoval:
            displayAmount = "\(String.amountIncrease) \(displayAmount)"
        case .liquidityAdd:
            displayAmount = "\(String.amountDecrease) \(displayAmount)"
        case .reward, .slash, .swap, .extrinsic:
            _ = displayAmount
        }

        let title = "\(asset.symbol)"
        let subtitle = asset.identifier

        let symbolViewModel: WalletImageViewModelProtocol?
        if let assetInfo = assetManager.assetInfo(for: asset.identifier),
           let iconString = assetInfo.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            symbolViewModel = nil
        }

        let viewModel = WalletTokenViewModel(
            state: .init(isSelecting: true, canSelect: true),
            header: asset.platform?.value(for: locale) ?? "",
            title: title,
            subtitle: subtitle,
            details: displayAmount,
            icon: nil,
            iconViewModel: symbolViewModel
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
    }

    private func populateDate(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let transactionDate = Date(timeIntervalSince1970: TimeInterval(data.timestamp))

        let timeDetails = dateFormatter.value(for: locale).string(from: transactionDate)

        let title = R.string.localizable.transactionDate(preferredLanguages: locale.rLanguages)

        let viewModel = WalletNewFormDetailsViewModel(title: title, titleIcon: nil, details: timeDetails, detailsIcon: nil)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateSwapInput(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let title = R.string.localizable.swapInputTitle(preferredLanguages: locale.rLanguages)

        guard let asset = assets.first(where: { $0.identifier == data.peerId }),
              let amount = AmountDecimal(string: data.details) else {
            return
        }

        let formatter = (amountFormatterFactory as? AmountFormatterFactory)!.createShortFormatter(for: asset)
        guard let displayAmount = formatter.value(for: locale).stringFromDecimal(amount.decimalValue) else {
            return
        }

        let viewModel = WalletNewFormDetailsViewModel(title: title, titleIcon: nil, details: displayAmount, detailsIcon: nil)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateSwapAlgorythm(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let title = R.string.localizable.polkaswapMarketTitle(preferredLanguages: locale.rLanguages)
        let type = LiquiditySourceType(rawValue: data.peerName ?? "")
        let details = type?.titleForLocale(locale)

        let viewModel = WalletNewFormDetailsViewModel(title: title, titleIcon: nil, details: details, detailsIcon: nil)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }
}

extension TransactionDetailsViewModelFactory: WalletTransactionDetailsFactoryOverriding {
    func createViewModelsFromTransaction(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        guard let type = TransactionType(rawValue: data.type) else {
            var viewModels: [WalletFormViewBindingProtocol] = []
            populateHeader(into: &viewModels, data: data, locale: locale)
            populateStatus(into: &viewModels, data: data, locale: locale)
            Logger.shared.warning("transaction details unknown")
            return viewModels
        }

        switch type {
        case .incoming, .outgoing:
            return transferTransactions(data: data, commandFactory: commandFactory)

        case .swap:
            return swapTransactions(data: data, commandFactory: commandFactory)

        case .liquidityAdd, .liquidityRemoval:
            return liquidityTransactions(data: data, commandFactory: commandFactory)

        case .reward, .slash, .extrinsic:
            Logger.shared.warning("transaction details unknown")
            return []
        }
    }

    private func transferTransactions(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol
    ) -> [WalletFormViewBindingProtocol]? {
        let locale = LocalizationManager.shared.selectedLocale
        let chain: Chain = .sora
        var viewModels: [WalletFormViewBindingProtocol] = []

        populateHeader(into: &viewModels, data: data, locale: locale)
        populateStatus(into: &viewModels, data: data, locale: locale)

        guard let peerAddress = data.peerName,
              let type = TransactionType(rawValue: data.type)
        else { return viewModels }

        let name = account.address

        populateDate(into: &viewModels, data: data, locale: locale)

        if type == .outgoing {
            populateFeeAmount(in: &viewModels, data: data, locale: locale)
        }
        populateTransactionId(
            in: &viewModels,
            data: data,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        if type == .incoming {
            populateSender(
                in: &viewModels,
                address: peerAddress,
                chain: chain,
                commandFactory: commandFactory,
                locale: locale
            )
            populateReceiver(
                in: &viewModels,
                address: name,
                chain: chain,
                commandFactory: commandFactory,
                locale: locale
            )
        } else {
            populateSender(
                in: &viewModels,
                address: name,
                chain: chain,
                commandFactory: commandFactory,
                locale: locale
            )
            populateReceiver(
                in: &viewModels,
                address: peerAddress,
                chain: chain,
                commandFactory: commandFactory,
                locale: locale
            )
        }

        return viewModels
    }

    private func swapTransactions(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol
    ) -> [WalletFormViewBindingProtocol]? {
        let locale = LocalizationManager.shared.selectedLocale
        let chain: Chain = .sora
        var viewModels: [WalletFormViewBindingProtocol] = []

        let name = account.address

        populateHeader(into: &viewModels, data: data, locale: locale)
        populateStatus(into: &viewModels, data: data, locale: locale)
        populateSwapInput(into: &viewModels, data: data, locale: locale)
        populateSwapAlgorythm(into: &viewModels, data: data, locale: locale)
        populateDate(into: &viewModels, data: data, locale: locale)
        populateFeeAmount(in: &viewModels, data: data, locale: locale)
        populateTransactionId(
            in: &viewModels,
            data: data,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )
        populateAccount(
            in: &viewModels,
            address: name,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        return viewModels
    }

    private func liquidityTransactions(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol
    ) -> [WalletFormViewBindingProtocol]? {
        let locale = LocalizationManager.shared.selectedLocale
        let chain: Chain = .sora
        var viewModels: [WalletFormViewBindingProtocol] = []

        let name = account.address

        populatePeerHeader(into: &viewModels, data: data, locale: locale)
        populateHeader(into: &viewModels, data: data, locale: locale)
        populateStatus(into: &viewModels, data: data, locale: locale)
        populateDate(into: &viewModels, data: data, locale: locale)
        populateFeeAmount(in: &viewModels, data: data, locale: locale)
        populateTransactionId(
            in: &viewModels,
            data: data,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )
        populateReceiver(
            in: &viewModels,
            address: name,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        return viewModels
    }

    func createAccessoryViewModelFromTransaction(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> AccessoryViewModelProtocol? {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            return nil
        }
        let locale = LocalizationManager.shared.selectedLocale
        let receiverInfo = ReceiveInfo(
            accountId: data.peerId,
            assetId: asset.identifier,
            amount: data.amount,
            details: nil
        )

        let transferPayload = TransferPayload(
            receiveInfo: receiverInfo,
            receiverName: data.peerName ?? ""
        )
        let command = commandFactory.prepareTransfer(with: transferPayload)
        command.presentationStyle = .push(hidesBottomBar: true)

        let action: String

        if data.status == .rejected && data.transactionType != .swap {
            action = R.string.localizable.commonRetry(preferredLanguages: locale.rLanguages)
        } else {
            switch data.transactionType {
            case .incoming:
                action = R.string.localizable
                    .walletTxDetailsSendBack(preferredLanguages: locale.rLanguages)
            case .outgoing:
                action = R.string.localizable
                    .walletTxDetailsSendAgain(preferredLanguages: locale.rLanguages)
            case .reward, .slash, .swap, .extrinsic, .liquidityAdd, .liquidityRemoval:
                return nil
            }
        }
        return AccessoryViewModel(title: "", action: action)
    }
}
