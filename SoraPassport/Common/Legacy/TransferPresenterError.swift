/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/


import Foundation

public enum TransferPresenterError: Error {
    case missingMetadata
    case missingBalances
    case missingAsset
}

extension TransferPresenterError: WalletErrorContentConvertible {
    public func toErrorContent(for locale: Locale?) -> WalletErrorContentProtocol {
        let message: String

        switch self {
        case .missingAsset:
            message = L10n.Amount.Error.asset
        case .missingBalances:
            message = L10n.Amount.Error.balance
        case .missingMetadata:
            message = L10n.Amount.Error.transfer
        }

        return WalletErrorContent(title: L10n.Common.error, message: message)
    }
}
