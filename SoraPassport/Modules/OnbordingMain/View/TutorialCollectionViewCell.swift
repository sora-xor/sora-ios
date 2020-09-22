/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class TutorialCollectionViewCell: UICollectionViewCell {
    @IBOutlet private(set) var iconImageView: UIImageView!
    @IBOutlet private(set) var detailsLabel: UILabel!

    func bind(viewModel: TutorialViewModelProtocol) {
        iconImageView.image = viewModel.image
        detailsLabel.text = viewModel.details

        setNeedsLayout()
    }
}
