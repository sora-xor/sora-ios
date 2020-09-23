/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet

final class WalletHistoryViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String { R.reuseIdentifier.walletHistoryCellId.identifier }
    var itemHeight: CGFloat { 55.0 }

    let title: String
    let note: String
    let icon: UIImage?
    let amount: String
    let date: String
    let isIncome: Bool
    let command: WalletCommandProtocol?

    init(title: String,
         note: String,
         icon: UIImage?,
         amount: String,
         date: String,
         isIncome: Bool,
         command: WalletCommandProtocol?) {
        self.title = title
        self.note = note
        self.icon = icon
        self.amount = amount
        self.date = date
        self.isIncome = isIncome
        self.command = command
    }
}
