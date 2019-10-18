/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI

final class WalletEmptyStateDataSource {
    var titleForEmptyState: String?
    var imageForEmptyState: UIImage?
    var titleColorForEmptyState: UIColor? = UIColor.emptyStateTitle
    var titleFontForEmptyState: UIFont? = UIFont.emptyStateTitle
    var verticalSpacingForEmptyState: CGFloat? = 16.0
    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy = .none

    init(title: String, image: UIImage? = nil) {
        self.titleForEmptyState = title
        self.imageForEmptyState = image
    }
}

extension WalletEmptyStateDataSource: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        return nil
    }
}
