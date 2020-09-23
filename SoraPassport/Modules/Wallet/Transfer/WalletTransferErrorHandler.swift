/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

struct WalletTransferErrorHandler: OperationDefinitionErrorHandling {
    let xorAsset: WalletAsset
    let ethAsset: WalletAsset
    let formatterFactory: NumberFormatterFactoryProtocol

    func mapError(_ error: Error, locale: Locale) -> OperationDefinitionErrorMapping? {
        if
            let validatorError = error as? TransferValidatingError,
            case .unsufficientFunds(let assetId, let balance) = validatorError {

            if ethAsset.identifier == assetId {
                let formatter = formatterFactory.createTokenFormatter(for: ethAsset).value(for: locale)
                let formattedAmount = formatter.string(from: balance) ?? balance.stringWithPointSeparator
                let message = R.string.localizable.transferUnsuffientFundsFormat(ethAsset.name.value(for: locale),
                                                                                 formattedAmount,
                                                                                 preferredLanguages: locale.rLanguages)
                return OperationDefinitionErrorMapping(type: .fee, message: message)
            } else {
                let formatter = formatterFactory.createTokenFormatter(for: xorAsset).value(for: locale)
                let formattedAmount = formatter.string(from: balance) ?? balance.stringWithPointSeparator
                let message = R.string.localizable.transferUnsuffientFundsFormat(xorAsset.name.value(for: locale),
                                                                                 formattedAmount,
                                                                                 preferredLanguages: locale.rLanguages)
                return OperationDefinitionErrorMapping(type: .amount, message: message)
            }

        }

        return nil
    }
}
