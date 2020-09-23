/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

struct WalletTransferViewModelFactoryV16 {
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let xorAsset: WalletAsset

    init(amountFormatterFactory: NumberFormatterFactoryProtocol,
         xorAsset: WalletAsset) {
        self.amountFormatterFactory = amountFormatterFactory
        self.xorAsset = xorAsset
    }
}

extension WalletTransferViewModelFactoryV16: TransferViewModelFactoryOverriding {
    func createReceiverViewModel(_ inputState: TransferInputState,
                                 payload: TransferPayload,
                                 locale: Locale) throws ->  MultilineTitleIconViewModelProtocol? {
        if payload.receiverName.isEmpty {
            return MultilineTitleIconViewModel(text: payload.receiveInfo.accountId,
                                               icon: R.image.iconSoraXor())
        } else {
            return nil
        }
    }

    func createSelectedAssetViewModel(_ inputState: TransferInputState,
                                      selectedAssetState: SelectedAssetState,
                                      payload: TransferPayload,
                                      locale: Locale) throws -> AssetSelectionViewModelProtocol? {
        let title: String
        let subtitle: String
        let details: String

        let asset = inputState.selectedAsset

        if let platform = asset.platform?.value(for: locale) {
            title = platform
            subtitle = asset.name.value(for: locale)
        } else {
            title = asset.name.value(for: locale)
            subtitle = ""
        }

        let amountFormatter = amountFormatterFactory.createDisplayFormatter(for: asset)

        if let balanceData = inputState.balance,
            let formattedBalance = amountFormatter.value(for: locale)
                .string(from: balanceData.balance.decimalValue as NSNumber) {
            details = "\(asset.symbol)\(formattedBalance)"
        } else {
            details = ""
        }

        let icon: UIImage? = R.image.iconSoraXor()

        return AssetSelectionViewModel(title: title,
                                       subtitle: subtitle,
                                       details: details,
                                       icon: icon,
                                       state: selectedAssetState)
    }

    func createAssetSelectionTitle(_ inputState: TransferInputState,
                                   payload: TransferPayload,
                                   locale: Locale) throws -> String? {
        let assetState = SelectedAssetState(isSelecting: false, canSelect: false)

        guard let viewModel = try createSelectedAssetViewModel(inputState,
                                                               selectedAssetState: assetState,
                                                               payload: payload,
                                                               locale: locale) else {
            return nil
        }

        if !viewModel.details.isEmpty {
            return "\(viewModel.title) - \(viewModel.details)"
        } else {
            return viewModel.title
        }
    }

    func createAccessoryViewModel(_ inputState: TransferInputState,
                                  payload: TransferPayload?,
                                  locale: Locale) throws -> AccessoryViewModelProtocol? {
        let action = R.string.localizable.transactionContinue(preferredLanguages: locale.rLanguages)
        return AccessoryViewModel(title: "", action: action)
    }
}
