/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import CommonWallet

final class WalletHistoryCell: UITableViewCell {
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var noteLabel: UILabel!
    @IBOutlet private var amountLabel: UILabel!
    @IBOutlet private var dateLabel: UILabel!

    @IBOutlet private var titleLabelCenterConstraints: NSLayoutConstraint!
    @IBOutlet private var titleLabelTopConstraints: NSLayoutConstraint!

    private(set) var viewModel: WalletViewModelProtocol?
}

extension WalletHistoryCell: WalletViewProtocol {
    func bind(viewModel: WalletViewModelProtocol) {
        if let transactionViewModel = viewModel as? WalletHistoryViewModel {
            self.viewModel = transactionViewModel

            iconImageView.image = transactionViewModel.icon
            titleLabel.text = transactionViewModel.title
            noteLabel.text = transactionViewModel.note
            amountLabel.text = transactionViewModel.amount
            dateLabel.text = transactionViewModel.date

            amountLabel.textColor = transactionViewModel.isIncome ?
                UIColor(red: 71.0 / 255.0, green: 158.0 / 255.0, blue: 108.0 / 255.0, alpha: 1.0) :
                UIColor.black

            if transactionViewModel.note.isEmpty {
                titleLabelCenterConstraints.isActive = true
                titleLabelTopConstraints.isActive = false
            } else {
                titleLabelCenterConstraints.isActive = false
                titleLabelTopConstraints.isActive = true
            }

            setNeedsLayout()
        }
    }
}
