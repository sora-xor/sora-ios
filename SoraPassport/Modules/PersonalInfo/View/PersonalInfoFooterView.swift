/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class PersonalInfoFooterView: UIView {
    @IBOutlet private var titleLabel: UILabel!

    @IBOutlet private var leadingConstraints: NSLayoutConstraint!
    @IBOutlet private var trallingConstraints: NSLayoutConstraint!
    @IBOutlet private var topConstraints: NSLayoutConstraint!
    @IBOutlet private var titleLeadingConstraints: NSLayoutConstraint!

    var contentInsets: UIEdgeInsets {
        set {
            leadingConstraints.constant = newValue.left
            titleLeadingConstraints.constant = newValue.left
            trallingConstraints.constant = newValue.right
            topConstraints.constant = newValue.top

            setNeedsLayout()
        }

        get {
            return UIEdgeInsets(top: topConstraints.constant,
                                left: leadingConstraints.constant,
                                bottom: 0.0,
                                right: trallingConstraints.constant)
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let availableWidth = size.width - leadingConstraints.constant - trallingConstraints.constant

        let textSize = titleLabel.sizeThatFits(CGSize(width: availableWidth,
                                                      height: CGFloat.greatestFiniteMagnitude))

        let height = topConstraints.constant + textSize.height

        return CGSize(width: size.width, height: height)
    }

    func bind(viewModel: PersonalInfoFooterViewModel) {
        titleLabel.text = viewModel.text
    }
}
