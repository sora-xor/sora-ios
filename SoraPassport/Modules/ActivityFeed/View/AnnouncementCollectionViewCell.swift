/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class AnnouncementCollectionViewCell: UICollectionViewCell {
    @IBOutlet private(set) var detailsLabel: UILabel!

    func bind(viewModel: AnnouncementItemViewModelProtocol) {
        detailsLabel.text = viewModel.content.message
    }
}
