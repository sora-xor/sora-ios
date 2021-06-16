/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import FearlessUtils

struct WalletTransferViewModelFactory {

    weak var commandFactory: WalletCommandFactoryProtocol?

    private let iconGenerator = PolkadotIconGenerator()
    let assets: [WalletAsset]
    let amountFormatterFactory: NumberFormatterFactoryProtocol

    init(assets: [WalletAsset],
         amountFormatterFactory: NumberFormatterFactoryProtocol) {
        self.assets = assets
        self.amountFormatterFactory = amountFormatterFactory
    }

    func createAssetTransferStateIconFromAmount(_ totalAmount: Decimal,
                                                tokens: TokenBalancesData,
                                                receiver: String,
                                                feeDescriptions: [FeeDescription]) -> UIImage? {
        if feeDescriptions
            .first(where: { $0.context?[WalletOperationContextKey.Receiver.isMine] != nil }) != nil {
            if NSPredicate.ethereumAddress.evaluate(with: receiver) {
                return R.image.assetVal()
            } else {
                return R.image.assetValErc()
            }
        }

        if NSPredicate.ethereumAddress.evaluate(with: receiver) {
             if totalAmount <= tokens.ethereum {
                return R.image.assetValErc()
            } else if totalAmount <= tokens.soranet {
                return  R.image.assetVal()
            } else {
                return R.image.iconCrossChain()
            }
        } else {
            if totalAmount <= tokens.soranet {
                return R.image.assetVal()
            } else if tokens.soranet == 0.0 && totalAmount <= tokens.ethereum {
                return R.image.assetValErc()
            } else {
                return R.image.iconCrossChain()
            }
        }
    }
}

extension WalletTransferViewModelFactory: TransferViewModelFactoryOverriding {

    func createReceiverViewModel(_ inputState: TransferInputState,
                                 payload: TransferPayload,
                                 locale: Locale) throws ->  MultilineTitleIconViewModelProtocol? {

        let icon = try iconGenerator.generateFromAddress(payload.receiverName)
            .imageWithFillColor(.white,
                                size: CGSize(width: 24.0, height: 24.0),
                                contentScale: UIScreen.main.scale)

        let command = SendToContactCommand(nextAction: {
            UIPasteboard.general.string = payload.receiverName
            let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages))
            try? commandFactory?.preparePresentationCommand(for: success).execute()
        })

        return WalletSoraReceiverViewModel(text: payload.receiverName,
                                           icon: icon,
                                           title: R.string.localizable.transactionReceiverTitle(preferredLanguages: locale.rLanguages),
                                           command: command)

    }

    func createSelectedAssetViewModel(_ inputState: TransferInputState,
                                      selectedAssetState: SelectedAssetState,
                                      payload: TransferPayload,
                                      locale: Locale) throws -> AssetSelectionViewModelProtocol? {
        let title: String
        let subtitle: String
        let details: String

        guard
            let asset = assets
                .first(where: { $0.identifier == payload.receiveInfo.assetId }),
            let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        title =  "\(asset.symbol)"
        subtitle = assetId.chainId

        let amountFormatter = amountFormatterFactory.createDisplayFormatter(for: asset)

        if let balanceData = inputState.balance,
            let formattedBalance = amountFormatter.value(for: locale)
                .string(from: balanceData.balance.decimalValue as NSNumber) {
            details = "\(formattedBalance)"
        } else {
            details = ""
        }

        return AssetSelectionViewModel(title: title,
                                       subtitle: subtitle,
                                       details: details,
                                       icon: assetId.icon,
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
