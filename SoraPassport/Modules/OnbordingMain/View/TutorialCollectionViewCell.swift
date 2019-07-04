/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

final class TutorialCollectionViewCell: UICollectionViewCell {
    @IBOutlet private(set) var iconImageView: UIImageView!
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var detailsLabel: UILabel!

    func bind(viewModel: TutorialViewModelProtocol) {
        iconImageView.image = viewModel.image
        titleLabel.text = viewModel.title
        detailsLabel.text = viewModel.details

        setNeedsLayout()
    }
}
