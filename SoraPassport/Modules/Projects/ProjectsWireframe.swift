/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

final class ProjectsWireframe: ProjectsWireframeProtocol {
    private lazy var inputTransitioningHandler = ActionPresentationFactory()

    func showVotingView(from view: ProjectsViewProtocol?,
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

    func showProjectDetails(from view: ProjectsViewProtocol?,
                            projectId: String) {
        guard let projectDetailsView = ProjectDetailsViewFactory.createView(for: projectId) else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            projectDetailsView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(projectDetailsView.controller, animated: true)
        }
    }

    func showVotingHistory(from view: ProjectsViewProtocol?) {
        guard let votesHistoryView = VotesHistoryViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            votesHistoryView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(votesHistoryView.controller, animated: true)
        }
    }
}
