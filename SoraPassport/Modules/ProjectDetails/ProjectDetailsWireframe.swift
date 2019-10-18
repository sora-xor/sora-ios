/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SKPhotoBrowser

final class ProjectDetailsWireframe: ProjectDetailsWireframeProtocol {
    private lazy var inputTransitioningHandler = ActionPresentationFactory()

    func showVotingView(from view: ProjectDetailsViewProtocol?,
                        with model: VoteViewModelProtocol,
                        delegate: VoteViewDelegate?) {
        guard let voteController = VoteViewFactory(transitioningDelegate: inputTransitioningHandler)
            .createVoteViewController(with: model, delegate: delegate) else {
                return
        }

        if let presentingViewController = view?.controller {
            presentingViewController.present(voteController,
                                             animated: true,
                                             completion: nil)
        }
    }

    func close(view: ProjectDetailsViewProtocol?) {
        view?.controller.navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func showVotesHistoryView(from view: ProjectDetailsViewProtocol?) {
        guard let votesHistoryView = VotesHistoryViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            votesHistoryView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(votesHistoryView.controller, animated: true)
        }
    }
}
