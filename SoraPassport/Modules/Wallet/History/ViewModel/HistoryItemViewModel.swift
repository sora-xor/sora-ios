/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import CommonWallet
import Foundation

final class HistoryItemViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String {
        switch type {
        case .incoming, .outgoing, .extrinsic, .migration, .reward, .slash, .swap, .referral:
            return HistoryConstants.historyCellId
        case .liquidityAdd, .liquidityAddNewPool, .liquidityAddToExistingPoolFirstTime, .liquidityRemoval:
            return HistoryConstants.liquidityHistoryCellId
        }
    }

    var itemHeight: CGFloat { HistoryConstants.historyHeight }

    let title: String
    let details: String
    let amount: NSAttributedString
    let type: TransactionType
    let status: AssetTransactionStatus
    let imageViewModel: WalletImageViewModelProtocol?
    let assetImageViewModel: WalletImageViewModelProtocol?
    let peerImageViewModel: WalletImageViewModelProtocol?
    let command: WalletCommandProtocol?

    init(title: String,
         details: String,
         amount: NSAttributedString,
         type: TransactionType,
         status: AssetTransactionStatus,
         imageViewModel: WalletImageViewModelProtocol?,
         assetImageViewModel: WalletImageViewModelProtocol?,
         peerImageViewModel: WalletImageViewModelProtocol?,
         command: WalletCommandProtocol?) {
        self.title = title
        self.details = details
        self.amount = amount
        self.type = type
        self.status = status
        self.imageViewModel = imageViewModel
        self.assetImageViewModel = assetImageViewModel
        self.peerImageViewModel = peerImageViewModel
        self.command = command
    }
}

final class HistorySwapViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String {
        HistoryConstants.historyCellId
    }

    var itemHeight: CGFloat { HistoryConstants.historyHeight }

    let title: NSAttributedString
    let details: String
    let amount: NSAttributedString
    let type: TransactionType
    let status: AssetTransactionStatus
    let imageViewModel: WalletImageViewModelProtocol?
    let assetImageViewModel: WalletImageViewModelProtocol?
    let peerImageViewModel: WalletImageViewModelProtocol?
    let command: WalletCommandProtocol?

    init(title: NSAttributedString,
         details: String,
         amount: NSAttributedString,
         type: TransactionType,
         status: AssetTransactionStatus,
         imageViewModel: WalletImageViewModelProtocol?,
         assetImageViewModel: WalletImageViewModelProtocol?,
         peerImageViewModel: WalletImageViewModelProtocol?,
         command: WalletCommandProtocol?) {
        self.title = title
        self.details = details
        self.amount = amount
        self.type = type
        self.status = status
        self.imageViewModel = imageViewModel
        self.assetImageViewModel = assetImageViewModel
        self.peerImageViewModel = peerImageViewModel
        self.command = command
    }
}
