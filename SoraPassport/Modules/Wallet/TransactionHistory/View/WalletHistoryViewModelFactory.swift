/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import SoraFoundation

final class WalletHistoryViewModelFactory {
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let nameIconStyle: WalletNameIconStyleProtocol
    let assets: [WalletAsset]
    let accountId: String
    let ethereumAddress: String

    init(amountFormatterFactory: NumberFormatterFactoryProtocol,
         dateFormatter: LocalizableResource<DateFormatter>,
         nameIconStyle: WalletNameIconStyleProtocol,
         assets: [WalletAsset],
         accountId: String,
         ethereumAddress: String) {
        self.amountFormatterFactory = amountFormatterFactory
        self.dateFormatter = dateFormatter
        self.nameIconStyle = nameIconStyle
        self.assets = assets
        self.accountId = accountId
        self.ethereumAddress = ethereumAddress
    }

    weak var commandFactory: WalletCommandFactoryProtocol?

    func createIconFromData(_ data: AssetTransactionData, locale: Locale) -> UIImage? {
        switch data.status {
        case .pending:
            return R.image.iconTxPending()
        case .rejected:
            return R.image.iconTxFailed()
        case .commited:
            if NSPredicate.ethereumAddress.evaluate(with: data.peerId) {
                return R.image.iconValErc()
            } else if data.type == WalletTransactionTypeValue.deposit.rawValue {
                return R.image.iconVal()
            } else {
                let asset = assets.first { data.assetId == $0.identifier }
                return asset?.icon
            }
        }
    }

    func createTitleFromData(_ data: AssetTransactionData, locale: Locale) -> String {
        guard let transactionType = WalletTransactionTypeValue(rawValue: data.type) else {
            return ""
        }

        if data.peerId == accountId {
            return R.string.localizable
                .walletHistoryToMySoranetTitle(preferredLanguages: locale.rLanguages)
        }

        if
            data.peerId.lowercased() == ethereumAddress.lowercased() ||
            data.details.lowercased() == ethereumAddress.lowercased() {
            return R.string.localizable
                .walletHistoryToMyEthereumTitle(preferredLanguages: locale.rLanguages)
        }

        switch transactionType {
        case .reward:
            if let peerName = data.peerName {
                return peerName
            } else {
                return R.string.localizable
                    .walletHistoryRewardFromSystem(preferredLanguages: locale.rLanguages)
            }
        case .incoming:
            if NSPredicate.ethereumAddress.evaluate(with: data.peerId) {
                return R.string.localizable
                    .walletHistoryFromEthereumAddressTitle(preferredLanguages: locale.rLanguages)
            } else if let peerName = data.peerName {
                return peerName
            } else {
                return R.string.localizable
                    .walletHistoryFromSoranetAddressTitle(preferredLanguages: locale.rLanguages)
            }
        case .outgoing:
            if NSPredicate.ethereumAddress.evaluate(with: data.peerId) {
                return R.string.localizable
                    .walletHistoryToEthereumAddress(preferredLanguages: locale.rLanguages)
            } else if let peerName = data.peerName {
                return peerName
            } else {
                return R.string.localizable
                    .walletHistoryToSoranetAccount(preferredLanguages: locale.rLanguages)
            }
        case .deposit:
            return R.string.localizable
                .walletHistoryToMySoranetTitle(preferredLanguages: locale.rLanguages)
        case .withdraw:
            return R.string.localizable
                .walletHistoryToEthereumAddress(preferredLanguages: locale.rLanguages)
        }
    }

    func createDetailsFromData(_ data: AssetTransactionData, locale: Locale) -> String {
        guard let transactionType = WalletTransactionTypeValue(rawValue: data.type) else {
            return ""
        }

        if data.peerId == accountId {
            return accountId
        }

        if
            data.peerId.lowercased() == ethereumAddress.lowercased() ||
            data.details.lowercased() == ethereumAddress.lowercased() {
            return ethereumAddress
        }

        switch transactionType {
        case .reward:
            return data.details
        case .incoming:
            if NSPredicate.ethereumAddress.evaluate(with: data.peerId) {
                return data.peerId
            } else if data.peerName != nil {
                return data.details
            } else {
                return data.peerId
            }
        case .outgoing:
            if NSPredicate.ethereumAddress.evaluate(with: data.peerId) {
                return data.peerId
            } else if data.peerName != nil {
                return data.details
            } else {
                return data.peerId
            }
        case .deposit:
            return accountId
        case .withdraw:
            if NSPredicate.ethereumAddress.evaluate(with: data.details) {
                return data.details
            } else {
                return data.peerId
            }
        }
    }

    func createAmountFromData(_ data: AssetTransactionData, locale: Locale) -> String {
        let asset = assets.first { data.assetId == $0.identifier }
        let tokenFormatter = amountFormatterFactory.createTokenFormatter(for: asset)

        guard
            let transactionType = WalletTransactionTypeValue(rawValue: data.type),
            let amount = tokenFormatter.value(for: locale)
            .string(from: data.amount.decimalValue) else {
            return ""
        }

        switch transactionType {
        case .incoming:
            return "\(String.amountIncrease) \(amount)"
        case .outgoing:
            return "\(String.amountDecrease) \(amount)"
        case .withdraw:
            if
                data.peerId.lowercased() != ethereumAddress.lowercased(),
                data.details.lowercased() != ethereumAddress.lowercased() {
                return "\(String.amountDecrease) \(amount)"
            } else {
                return amount
            }
        default:
            return amount
        }

    }

    func createDateFromData(_ data: AssetTransactionData, locale: Locale) -> String {
        dateFormatter
            .value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))
    }
}

extension WalletHistoryViewModelFactory: HistoryItemViewModelFactoryProtocol {
    func createItemFromData(_ data: AssetTransactionData, commandFactory: WalletCommandFactoryProtocol, locale: Locale) throws -> WalletViewModelProtocol {
        let icon = createIconFromData(data, locale: locale)
        let title = createTitleFromData(data, locale: locale)
        let details = createDetailsFromData(data, locale: locale)
        let amount = createAmountFromData(data, locale: locale)
        let date = createDateFromData(data, locale: locale)
        let command = commandFactory.prepareTransactionDetailsCommand(with: data)

        let isIncome: Bool

        if data.type == WalletTransactionTypeValue.incoming.rawValue {
            isIncome = data.status == .commited
        } else {
            isIncome = false
        }

        return WalletHistoryViewModel(title: title,
                                      note: details,
                                      icon: icon,
                                      amount: amount,
                                      date: date,
                                      isIncome: isIncome,
                                      command: command)
    }
}
