/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

struct WalletConfirmationViewModelFactory {
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let feeDisplayFactory: FeeDisplaySettingsFactoryProtocol
    let generatingIconStyle: WalletNameIconStyleProtocol
    let xorAsset: WalletAsset
    let ethAsset: WalletAsset

    func calculateTotalAmount(from payload: ConfirmationPayload) -> Decimal {
        return payload.transferInfo.fees
            .reduce(payload.transferInfo.amount.decimalValue) { (result, fee) in
            if fee.feeDescription.assetId == payload.transferInfo.asset {
                return result + fee.value.decimalValue
            } else {
                return result
            }
        }
    }

    func createAssetTransferStateIconFromTokens(_ tokens: TokenBalancesData) -> UIImage? {
        if tokens.soranet > 0, tokens.ethereum > 0 {
            return R.image.iconCrossChain()
        } else if tokens.ethereum > 0 {
            return R.image.iconXorErc()
        } else {
            return R.image.iconSoraXor()
        }
    }

    func populateAsset(in viewModelList: inout [WalletFormViewBindingProtocol],
                       payload: ConfirmationPayload,
                       locale: Locale) {
        let headerTitle = R.string.localizable.transactionToken(preferredLanguages: locale.rLanguages)
        let headerViewModel = WalletFormDetailsHeaderModel(title: headerTitle)
        viewModelList.append(headerViewModel)

        let tokens = TokenBalancesData(sendingContext: payload.transferInfo.context ?? [:])
        let icon = createAssetTransferStateIconFromTokens(tokens)

        let title: String
        let subtitle: String

        if let platform = xorAsset.platform?.value(for: locale) {
            title = platform
            subtitle = xorAsset.name.value(for: locale)
        } else {
            title = xorAsset.name.value(for: locale)
            subtitle = ""
        }

        let tokenViewModel = WalletFormTokenViewModel(title: title,
                                                      subtitle: subtitle,
                                                      icon: icon)
        viewModelList.append(WalletFormSeparatedViewModel(content: tokenViewModel, borderType: [.bottom]))
    }

    func populateReceiver(in viewModelList: inout [WalletFormViewBindingProtocol],
                          payload: ConfirmationPayload,
                          locale: Locale) {
        let headerTitle: String
        let icon: UIImage?
        let title: String

        if NSPredicate.ethereumAddress.evaluate(with: payload.transferInfo.destination) {
            headerTitle = R.string.localizable.walletTransferToEthereum(preferredLanguages: locale.rLanguages)
            icon = R.image.iconXorErc()
            title = payload.transferInfo.destination
        } else if payload.receiverName.isEmpty {
            headerTitle = R.string.localizable.transactionReceiverTitle(preferredLanguages: locale.rLanguages)
            icon = R.image.iconSoraXor()
            title = payload.transferInfo.destination
        } else {
            title = payload.receiverName
            headerTitle = R.string.localizable.transactionReceiverTitle(preferredLanguages: locale.rLanguages)
            icon = generateReceiverIconForName(payload.receiverName, style: generatingIconStyle)
        }

        let headerViewModel = WalletFormDetailsHeaderModel(title: headerTitle)
        viewModelList.append(headerViewModel)

        let viewModel = WalletFormSingleHeaderModel(title: title, icon: icon)

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
    }

    func populateSendingAmount(in viewModelList: inout [WalletFormViewBindingProtocol],
                               payload: ConfirmationPayload,
                               locale: Locale) {
        let formatter = amountFormatterFactory.createTokenFormatter(for: xorAsset)

        let decimalAmount = payload.transferInfo.amount.decimalValue

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
                               payload: ConfirmationPayload,
                               locale: Locale) {
        let formatter = amountFormatterFactory.createTokenFormatter(for: xorAsset).value(for: locale)

        for fee in payload.transferInfo.fees
            where fee.feeDescription.assetId == payload.transferInfo.asset {

            let feeDisplaySettings = feeDisplayFactory
                .createFeeSettingsForId(fee.feeDescription.identifier)

            guard let decimalAmount = feeDisplaySettings
                .displayStrategy.decimalValue(from: fee.value.decimalValue) else {
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
                               payload: ConfirmationPayload,
                               locale: Locale) {
        for fee in payload.transferInfo.fees
            where fee.feeDescription.assetId != payload.transferInfo.asset {

            let formatter = amountFormatterFactory.createTokenFormatter(for: ethAsset).value(for: locale)

            let feeDisplaySettings = feeDisplayFactory
                .createFeeSettingsForId(fee.feeDescription.identifier)

            guard let decimalAmount = feeDisplaySettings
                .displayStrategy.decimalValue(from: fee.value.decimalValue) else {
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
                             payload: ConfirmationPayload,
                             locale: Locale) {

        let formatter = amountFormatterFactory.createTokenFormatter(for: xorAsset).value(for: locale)

        let totalAmountDecimal = calculateTotalAmount(from: payload)

        guard let totalAmount = formatter.string(from: totalAmountDecimal) else {
            return
        }

        let title = R.string.localizable.transactionTotal(preferredLanguages: locale.rLanguages)
        let viewModel = WalletFormSpentAmountModel(title: title,
                                                   amount: totalAmount)

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.top]))
    }

    func populateNote(in viewModelList: inout [WalletFormViewBindingProtocol],
                      payload: ConfirmationPayload,
                      locale: Locale) {
        let note = payload.transferInfo.details

        guard !note.isEmpty else {
            return
        }

        let title = R.string.localizable.transactionNote(preferredLanguages: locale.rLanguages)
        let headerViewModel = WalletFormDetailsHeaderModel(title: title,
                                                           icon: R.image.iconNote())
        viewModelList.append(headerViewModel)

        let viewModel = MultilineTitleIconViewModel(text: note)
        viewModelList.append(viewModel)
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
        populateNote(in: &viewModelList, payload: payload, locale: locale)
        populateTotalAmount(in: &viewModelList, payload: payload, locale: locale)
        populateSecondaryFees(in: &viewModelList, payload: payload, locale: locale)

        return viewModelList
    }

    func createAccessoryViewModelFromPayload(_ payload: ConfirmationPayload,
                                             locale: Locale) -> AccessoryViewModelProtocol? {
        AccessoryViewModel(title: "",
                           action: R.string.localizable.transactionConfirm(preferredLanguages: locale.rLanguages))
    }
}
