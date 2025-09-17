/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit
import SoraUI

final class EmptyStateViewController: UIViewController {
    var bottomInsets: CGFloat = 0.0

    override func viewDidLoad() {
        super.viewDidLoad()

        updateEmptyState(animated: true)
    }
}

extension EmptyStateViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate {
        return self
    }

    var emptyStateDataSource: EmptyStateDataSource {
        return self
    }

    var appearanceAnimatorForEmptyState: ViewAnimatorProtocol? {
        return TransformAnimator(from: CGAffineTransform(scaleX: 0.01, y: 0.01), to: .identity)
    }

    var displayInsetsForEmptyState: UIEdgeInsets {
        var insets = UIEdgeInsets.zero
        insets.bottom = bottomInsets
        return insets
    }
}

extension EmptyStateViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        return true
    }
}

extension EmptyStateViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        return nil
    }

    var imageForEmptyState: UIImage? {
        return UIImage(named: "emptyState")
    }

    var titleForEmptyState: String? {
        return "To be or not to be..."
    }

    var titleColorForEmptyState: UIColor? {
        return UIColor.black
    }

    var titleFontForEmptyState: UIFont? {
        return UIFont.boldSystemFont(ofSize: 16.0)
    }

    var verticalSpacingForEmptyState: CGFloat? {
        return 40.0
    }

    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy {
        return .none
    }
}
