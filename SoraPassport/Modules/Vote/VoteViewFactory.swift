/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol VoteViewFactoryProtocol {
    func createVoteViewController(with model: VoteViewModelProtocol,
                                  delegate: VoteViewDelegate?) -> UIViewController?
}

class VoteViewFactory {
    private weak var transitioningDelegate: UIViewControllerTransitioningDelegate?

    init(transitioningDelegate: UIViewControllerTransitioningDelegate?) {
        self.transitioningDelegate = transitioningDelegate
    }
}

extension VoteViewFactory: VoteViewFactoryProtocol {
    func createVoteViewController(with model: VoteViewModelProtocol,
                                  delegate: VoteViewDelegate?) -> UIViewController? {
        guard let view = UINib(resource: R.nib.voteView)
            .instantiate(withOwner: nil, options: nil).first as? VoteView else {
                return nil
        }

        view.normalDescriptionColor = .voteDescriptionNormal
        view.errorDescriptionColor = .voteDescriptionError

        let trackCornerRadius: CGFloat = 4.0
        let trackImageSize = CGSize(width: 12.0, height: 8.0)
        let resizableInsets = UIEdgeInsets(top: 0.0,
                                           left: trackCornerRadius,
                                           bottom: 0.0,
                                           right: trackCornerRadius)
        let minimumTrackImage = UIImage.background(from: .voteMinimumTrack,
                                                   size: trackImageSize,
                                                   cornerRadius: trackCornerRadius,
                                                   contentScale: UIScreen.main.scale)
        view.minimumTrackImage = minimumTrackImage?.resizableImage(withCapInsets: resizableInsets)

        let maximumTrackImage = UIImage.background(from: .voteMaximumTrack,
                                                   size: trackImageSize,
                                                   cornerRadius: trackCornerRadius,
                                                   contentScale: UIScreen.main.scale)
        view.maximumTrackImage = maximumTrackImage?.resizableImage(withCapInsets: resizableInsets)

        view.frame.size.width = min(UIScreen.main.bounds.size.width,
                                    UIScreen.main.bounds.size.height)
        view.delegate = delegate
        view.model = model

        let viewController = UIViewController()
        viewController.view = view
        viewController.transitioningDelegate = transitioningDelegate
        viewController.modalPresentationStyle = .custom

        return viewController
    }
}
