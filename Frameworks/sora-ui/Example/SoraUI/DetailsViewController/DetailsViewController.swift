/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit
import SoraUI

final class DetailsViewController: UIViewController {
    lazy var expansionAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()
    @IBOutlet var detailsView: DetailsTextView!
    @IBOutlet var heightConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()

        detailsView.delegate = self
    }
}

extension DetailsViewController: DetailsTextViewDelegate {
    func didChangeExpandingState(in detailsView: DetailsTextView) {
        var height: CGFloat = 160.0

        if detailsView.expanded, let text = detailsView.text {

            height = text.boundingRect(with: CGSize(width: detailsView.frame.size.width, height: CGFloat.greatestFiniteMagnitude),
                                       options: .usesLineFragmentOrigin,
                                       attributes: [.font: detailsView.textFont],
                                       context: nil).size.height
            height += detailsView.footerHeight
        }

        expansionAnimator.animate(block: {
            self.heightConstraint.constant = height
            self.view.layoutIfNeeded()
        }, completionBlock: nil)
    }
}
