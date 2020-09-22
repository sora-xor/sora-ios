/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class VotesHistoryTableViewCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var typeImageView: UIImageView!
    @IBOutlet private var amountLabel: UILabel!

    private(set) var viewModel: VotesHistoryItemViewModelProtocol?

    func bind(viewModel: VotesHistoryItemViewModelProtocol) {
        titleLabel.text = viewModel.title
        amountLabel.text = viewModel.amount

        switch viewModel.type {
        case .decrease:
            typeImageView.image = R.image.decreaseIcon()
        case .increase:
            typeImageView.image = R.image.increaseIcon()
        }
    }
}
