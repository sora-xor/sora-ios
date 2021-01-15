/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import SoraFoundation

//swiftlint:disable type_body_length
final class WalletTransactionDetailsFactory {
    let feeDisplayFactory: FeeDisplaySettingsFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let assets: [WalletAsset]
    let accountId: String
    let ethereumAddress: String
    let nameIconStyle: WalletNameIconStyleProtocol
    let soranetExplorerTemplate: String
    let ethereumExplorerTemplate: String

    weak var commandFactory: WalletCommandFactoryProtocol?

    init(feeDisplayFactory: FeeDisplaySettingsFactoryProtocol,
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         dateFormatter: LocalizableResource<DateFormatter>,
         assets: [WalletAsset],
         accountId: String,
         ethereumAddress: String,
         nameIconStyle: WalletNameIconStyleProtocol,
         soranetExplorerTemplate: String,
         ethereumExplorerTemplate: String) {
        self.dateFormatter = dateFormatter
        self.feeDisplayFactory = feeDisplayFactory
        self.amountFormatterFactory = amountFormatterFactory
        self.assets = assets
        self.accountId = accountId
        self.ethereumAddress = ethereumAddress
        self.nameIconStyle = nameIconStyle
        self.soranetExplorerTemplate = soranetExplorerTemplate
        self.ethereumExplorerTemplate = ethereumExplorerTemplate
    }

    private func populateStatus(into viewModels: inout [WalletFormViewBindingProtocol],
                                data: AssetTransactionData,
                                locale: Locale) {
        let detailsText: String
        let detailsIcon: UIImage?

        switch data.status {
        case .pending:
            detailsText = R.string.localizable
                .walletTxDetailsPending(preferredLanguages: locale.rLanguages)
            detailsIcon = R.image.iconTxStatusPending()
        case .commited:
            detailsText = R.string.localizable
                .walletTxDetailsCompleted(preferredLanguages: locale.rLanguages)
            detailsIcon = R.image.iconTxStatusSuccess()
        case .rejected:
            detailsText = R.string.localizable
                .walletTxDetailsRejected(preferredLanguages: locale.rLanguages)
            detailsIcon = R.image.iconTxStatusError()
        }

        let statusTitle = R.string.localizable
            .walletTxDetailsStatus(preferredLanguages: locale.rLanguages)
        let viewModel = WalletNewFormDetailsViewModel(title: statusTitle,
                                                      titleIcon: nil,
                                                      details: detailsText,
                                                      detailsIcon: detailsIcon)

        viewModels.append(viewModel)
    }

    private func populateDate(into viewModels: inout [WalletFormViewBindingProtocol],
                              data: AssetTransactionData,
                              locale: Locale) {
        let date = Date(timeIntervalSince1970: TimeInterval(data.timestamp))
        let dateString = dateFormatter.value(for: locale).string(from: date)

        let dateTitle = R.string.localizable
            .walletTxDetailsDate(preferredLanguages: locale.rLanguages)
        let viewModel = WalletNewFormDetailsViewModel(title: dateTitle,
                                                      titleIcon: nil,
                                                      details: dateString,
                                                      detailsIcon: nil)

        viewModels.append(viewModel)
    }

    func populateTransactions(into viewModels: inout [WalletFormViewBindingProtocol],
                              data: AssetTransactionData,
                              locale: Locale) {
        guard
            let context = data.context,
            (context.ethereumTxId != nil || context.soranetTxId != nil) else {
            return
        }

        let title = R.string.localizable
            .walletTxDetailsTransaction(preferredLanguages: locale.rLanguages)
        let headerViewModel = WalletFormSingleHeaderModel(title: title)

        let ethereumCommand: WalletCommandProtocol?
        let soranetCommand: WalletCommandProtocol?

        if let ethereumTxId = context.ethereumTxId {
            let txIdData = Data(hex: ethereumTxId)
            ethereumCommand = createCommandTx(txIdData.soraHexWithPrefix,
                                              isEthereum: true,
                                              locale: locale)
        } else {
            ethereumCommand = nil
        }

        if let soranetTxId = context.soranetTxId {
            soranetCommand = createCommandTx(soranetTxId, isEthereum: false, locale: locale)
        } else {
            soranetCommand = nil
        }

        let txViewModel = WalletTransactionsViewModel(ethereumCommand: ethereumCommand,
                                                    soranetCommand: soranetCommand)

        viewModels.append(headerViewModel)
        viewModels.append(txViewModel)
    }

    func createCommandTx(_ transactionId: String, isEthereum: Bool, locale: Locale) -> WalletCommandProtocol? {
        guard let commandFactory = commandFactory else {
            return nil
        }

        let title = R.string.localizable
            .commonSelectOption(preferredLanguages: locale.rLanguages)
        let actionSheet = UIAlertController(title: title,
                                            message: nil,
                                            preferredStyle: .actionSheet)

        let explorerTitle = R.string.localizable.commonOpenExplorer()
        let explorerAction = UIAlertAction(title: explorerTitle, style: .default) { _ in
            let template = isEthereum ? self.ethereumExplorerTemplate : self.soranetExplorerTemplate
            let builder = EndpointBuilder(urlTemplate: template)

            if let url = try? builder.buildParameterURL(transactionId) {
                let webViewController = WebViewFactory.createWebViewController(for: url, style: .automatic)

                let command = commandFactory.preparePresentationCommand(for: webViewController)
                command.presentationStyle = .modal(inNavigation: false)
                try? command.execute()
            }
        }

        let copyTitle = R.string.localizable
            .commonCopy(preferredLanguages: locale.rLanguages)
        let copyAction = UIAlertAction(title: copyTitle, style: .default) { _ in
            UIPasteboard.general.string = transactionId
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)

        actionSheet.addAction(explorerAction)
        actionSheet.addAction(copyAction)
        actionSheet.addAction(cancel)

        return commandFactory.preparePresentationCommand(for: actionSheet)
    }

    func populateSentAmount(in viewModelList: inout [WalletFormViewBindingProtocol],
                            data: AssetTransactionData,
                            locale: Locale) {
        let asset = assets.first(where: { $0.identifier == data.assetId })

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset)

        let decimalAmount = data.amount.decimalValue

        guard let amount = formatter.value(for: locale).string(from: decimalAmount) else {
            return
        }

        let title = R.string.localizable.transactionAmountTitle(preferredLanguages: locale.rLanguages)
        let viewModel = WalletNewFormDetailsViewModel(title: title,
                                                      titleIcon: nil,
                                                      details: amount,
                                                      detailsIcon: nil)
        viewModelList.append(viewModel)
    }

    func populateMainFeeAmount(in viewModelList: inout [WalletFormViewBindingProtocol],
                               data: AssetTransactionData,
                               locale: Locale) {

        let supported: [WalletTransactionTypeValue] = [.deposit, .withdraw, .outgoing]

        guard
            let type = WalletTransactionTypeValue(rawValue: data.type),
            supported.contains(type),
            let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            return
        }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

        for fee in data.fees where fee.assetId == asset.identifier {

            let feeDisplaySettings = feeDisplayFactory
                .createFeeSettingsForId(fee.identifier)

            guard let decimalAmount = feeDisplaySettings
                .displayStrategy.decimalValue(from: fee.amount.decimalValue) else {
                continue
            }

            guard let amount = formatter.string(from: decimalAmount) else {
                continue
            }

            let title = feeDisplaySettings.displayName.value(for: locale)

            let viewModel = WalletNewFormDetailsViewModel(title: title,
                                                          titleIcon: nil,
                                                          details: amount,
                                                          detailsIcon: nil)

            viewModelList.append(viewModel)
        }
    }

    func populateSecondaryFees(in viewModelList: inout [WalletFormViewBindingProtocol],
                               data: AssetTransactionData,
                               locale: Locale) {

        let supported: [WalletTransactionTypeValue] = [.deposit, .withdraw, .outgoing]
        guard
            let type = WalletTransactionTypeValue(rawValue: data.type),
            supported.contains(type) else {
            return
        }

        for fee in data.fees where fee.assetId != data.assetId {
            guard let asset = assets.first(where: { $0.identifier == fee.assetId }) else {
                continue
            }

            let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

            let feeDisplaySettings = feeDisplayFactory.createFeeSettingsForId(fee.identifier)

            guard let decimalAmount = feeDisplaySettings
                .displayStrategy.decimalValue(from: fee.amount.decimalValue) else {
                continue
            }

            guard let amount = formatter.string(from: decimalAmount) else {
                continue
            }

            let title = feeDisplaySettings.displayName.value(for: locale)

            let viewModel = WalletNewFormDetailsViewModel(title: title,
                                                          titleIcon: nil,
                                                          details: amount,
                                                          detailsIcon: nil)

            viewModelList.append(viewModel)
        }
    }

    func populateTotalAmount(in viewModelList: inout [WalletFormViewBindingProtocol],
                             data: AssetTransactionData,
                             locale: Locale) {

        let supported: [WalletTransactionTypeValue] = [.outgoing]

        guard
            let type = WalletTransactionTypeValue(rawValue: data.type),
            (supported.contains(type) || (type == .withdraw && data.peerId != ethereumAddress)) else {
            return
        }

        let asset = assets.first(where: { $0.identifier == data.assetId })

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

        let totalAmountDecimal: Decimal = data.fees
            .reduce(data.amount.decimalValue) { (result, fee) in
            if fee.assetId == data.assetId {
                return result + fee.amount.decimalValue
            } else {
                return result
            }
        }

        guard let totalAmount = formatter.string(from: totalAmountDecimal) else {
            return
        }

        let title = R.string.localizable.transactionTotal(preferredLanguages: locale.rLanguages)
        let viewModel = WalletFormSpentAmountModel(title: title,
                                                   amount: totalAmount)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.top])
        viewModelList.append(separator)
    }

    private func populateNote(into viewModels: inout [WalletFormViewBindingProtocol],
                              data: AssetTransactionData,
                              locale: Locale) {
        guard let type = WalletTransactionTypeValue(rawValue: data.type) else {
            return
        }

        var note: String = ""

        switch type {
        case .incoming, .outgoing, .reward:
            if !NSPredicate.ethereumAddress.evaluate(with: data.peerId) {
                note = data.details
            }
        default:
            break
        }

        guard !note.isEmpty else {
            return
        }

        let headerTitle = R.string.localizable
            .transactionNote(preferredLanguages: locale.rLanguages)
        let headerViewModel = WalletFormDetailsHeaderModel(title: headerTitle,
                                                           icon: R.image.iconNote())

        let noteViewModel = MultilineTitleIconViewModel(text: note, icon: nil)

        viewModels.append(headerViewModel)
        viewModels.append(noteViewModel)
    }

    private func populateFrom(into viewModels: inout [WalletFormViewBindingProtocol],
                              data: AssetTransactionData,
                              locale: Locale) {
        guard let type = WalletTransactionTypeValue(rawValue: data.type) else {
            return
        }

        switch type {
        case .incoming:
            let title: String

            if data.peerEthereumAddress != nil {
                title = R.string.localizable
                    .walletHistoryFromEthereumAddressTitle(preferredLanguages: locale.rLanguages)
            } else {
                title = R.string.localizable
                    .walletHistoryFromSoranetAddressTitle(preferredLanguages: locale.rLanguages)
            }

            populatePeerId(data.peerId,
                           asset: data.assetId,
                           title: title,
                           into: &viewModels,
                           locale: locale)
        case .outgoing:
            let title: String

            if data.peerEthereumAddress != nil {
                title = R.string.localizable
                    .walletHistoryFromEthereumAddressTitle(preferredLanguages: locale.rLanguages)
            } else {
                title = R.string.localizable
                    .walletHistoryFromSoranetAddressTitle(preferredLanguages: locale.rLanguages)
            }

            populatePeerId(data.peerEthereumAddress != nil ? self.ethereumAddress : self.accountId,
                           asset: data.assetId,
                           title: title,
                           into: &viewModels,
                           locale: locale)

        case .deposit:
            guard let address = data.peerEthereumAddress else {
                return
            }

            let title = ethereumAddress == address ?
                R.string.localizable
                    .walletHistoryFromEthereumAddressTitle(preferredLanguages: locale.rLanguages) :
                R.string.localizable
                    .walletHistoryFromEthereumAddressTitle(preferredLanguages: locale.rLanguages)

            populatePeerId(address,
                           asset: data.assetId,
                           title: title,
                           into: &viewModels,
                           locale: locale)
        case .withdraw:
            let title = R.string.localizable
                .walletHistoryFromSoranetAddressTitle(preferredLanguages: locale.rLanguages)

            populatePeerId(self.accountId,
                           asset: data.assetId,
                           title: title,
                           into: &viewModels,
                           locale: locale)

        default:
            break
        }
    }

    private func populateTo(into viewModels: inout [WalletFormViewBindingProtocol],
                            data: AssetTransactionData,
                            locale: Locale) {
        guard let type = WalletTransactionTypeValue(rawValue: data.type) else {
            return
        }

        switch type {
        case .incoming:
            let title: String

            if data.peerEthereumAddress != nil {
                title = R.string.localizable
                    .walletHistoryToEthereumAddress(preferredLanguages: locale.rLanguages)
            } else {
                title = R.string.localizable
                    .walletHistoryToSoranetAccount(preferredLanguages: locale.rLanguages)
            }

            populatePeerId(self.accountId,
                           asset: data.assetId,
                           title: title,
                           into: &viewModels,
                           locale: locale)
        case .outgoing:
            let title: String

            if data.peerEthereumAddress != nil {
                title = R.string.localizable
                    .walletHistoryToEthereumAddress(preferredLanguages: locale.rLanguages)
            } else {
                title = R.string.localizable
                    .walletHistoryToSoranetAccount(preferredLanguages: locale.rLanguages)
            }

            populatePeerId(data.peerId,
                           asset: data.assetId,
                           title: title,
                           into: &viewModels,
                           locale: locale)
        case .deposit:
            let title = R.string.localizable
                .walletHistoryToMySoranetTitle(preferredLanguages: locale.rLanguages)

            populatePeerId(accountId,
                           asset: data.assetId,
                           title: title,
                           into: &viewModels,
                           locale: locale)
        case .withdraw:
            guard let address = data.peerEthereumAddress else {
                return
            }

            let title = ethereumAddress == address ?
                R.string.localizable
                    .walletHistoryToMyEthereumTitle(preferredLanguages: locale.rLanguages) :
                R.string.localizable
                    .walletHistoryToEthereumAddress(preferredLanguages: locale.rLanguages)

            populatePeerId(address,
                           asset: data.assetId,
                           title: title,
                           into: &viewModels,
                           locale: locale)
        default:
            break
        }
    }

    private func populatePeerId(_ peerId: String, asset assetId: String,
                                title: String,
                                into viewModels: inout [WalletFormViewBindingProtocol],
                                locale: Locale) {
        guard let commandFactory = commandFactory else {
            return
        }

        let headerViewModel = WalletFormSingleHeaderModel(title: title)

        let command = createPeerActionCommand(from: commandFactory,
                                              peerId: peerId,
                                              locale: locale)

        let accountType: WalletAccountViewModel.AccountType

        if NSPredicate.ethereumAddress.evaluate(with: peerId) {
            accountType = .ethereum
        } else {
            accountType = assetId.contains(String.xor.lowercased()) ? .soranet : .val
        }

        let accountViewModel = WalletAccountViewModel(title: peerId,
                                                      type: accountType,
                                                      command: command)

        viewModels.append(headerViewModel)
        viewModels.append(accountViewModel)
    }

    private func createPeerActionCommand(from commandFactory: WalletCommandFactoryProtocol,
                                         peerId: String,
                                         locale: Locale) -> WalletCommandProtocol {

        let title = R.string.localizable
            .commonSelectOption(preferredLanguages: locale.rLanguages)
        let actionSheet = UIAlertController(title: title,
                                            message: nil,
                                            preferredStyle: .actionSheet)

        let copyTitle = R.string.localizable
            .commonCopy(preferredLanguages: locale.rLanguages)
        let copyAction = UIAlertAction(title: copyTitle, style: .default) { _ in
            UIPasteboard.general.string = peerId
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)

        actionSheet.addAction(copyAction)
        actionSheet.addAction(cancel)

        return commandFactory.preparePresentationCommand(for: actionSheet)
    }
}

extension WalletTransactionDetailsFactory: WalletTransactionDetailsFactoryOverriding {
    func createViewModelsFromTransaction(data: AssetTransactionData,
                                         commandFactory: WalletCommandFactoryProtocol,
                                         locale: Locale) -> [WalletFormViewBindingProtocol]? {
        var viewModels: [WalletFormViewBindingProtocol] = []

        populateStatus(into: &viewModels, data: data, locale: locale)
        populateDate(into: &viewModels, data: data, locale: locale)
        populateTransactions(into: &viewModels, data: data, locale: locale)
        populateFrom(into: &viewModels, data: data, locale: locale)
        populateTo(into: &viewModels, data: data, locale: locale)
        populateSentAmount(in: &viewModels, data: data, locale: locale)
        populateMainFeeAmount(in: &viewModels, data: data, locale: locale)
        populateNote(into: &viewModels, data: data, locale: locale)
        populateTotalAmount(in: &viewModels, data: data, locale: locale)
        populateSecondaryFees(in: &viewModels, data: data, locale: locale)

        return viewModels
    }

    func createAccessoryViewModelFromTransaction(data: AssetTransactionData,
                                                 commandFactory: WalletCommandFactoryProtocol,
                                                 locale: Locale) -> AccessoryViewModelProtocol? {
        let supported: [WalletTransactionTypeValue] = [.incoming, .outgoing, .deposit, .withdraw]
        guard
            let type = WalletTransactionTypeValue(rawValue: data.type),
            supported.contains(type) else {
            return nil
        }

        guard
            let asset = self.assets.first(where: { $0.identifier == data.assetId}),
            asset.modes.contains(.transfer) else { //xor no resend
            return nil
        }

        let title: String
        let icon: UIImage?

        if let ethereumAddress = data.peerEthereumAddress {
            title = ethereumAddress
            icon = R.image.iconValErc()
        } else if type == .deposit {
            title = accountId
            icon = R.image.iconXor()
        } else if let peerName = data.peerName {
            title = peerName
            icon = UIImage.createAvatar(fullName: peerName, style: nameIconStyle)
        } else {
            title = data.peerId
            icon = R.image.iconXor()
        }

        let action: String

        if data.status == .rejected {
            action = R.string.localizable.commonRetry()
        } else {
            switch type {
            case .outgoing, .withdraw, .deposit:
                action = R.string.localizable
                    .walletTxDetailsSendAgain(preferredLanguages: locale.rLanguages)
            case .incoming:
                action = R.string.localizable
                    .walletTxDetailsSendBack(preferredLanguages: locale.rLanguages)
            default:
                return nil
            }
        }

        return AccessoryViewModel(title: title, action: action, icon: icon)
    }
}
