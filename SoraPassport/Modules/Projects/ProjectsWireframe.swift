import Foundation

final class ProjectsWireframe: ProjectsWireframeProtocol {
    private lazy var inputTransitioningHandler = ActionPresentationFactory()

    func showVotingView(from view: ProjectsViewProtocol?,
                        with model: VoteViewModelProtocol,
                        style: VoteViewStyle,
                        delegate: VoteViewDelegate?) {
        guard let voteController = VoteViewFactory(transitioningDelegate: inputTransitioningHandler)
            .createVoteViewController(with: model, style: style, delegate: delegate) else {
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

        let navigationController = SoraNavigationController(rootViewController: projectDetailsView.controller)

        view?.controller.present(navigationController,
                                 animated: true,
                                 completion: nil)
    }

    func showReferendumDetails(from view: ProjectsViewProtocol?,
                               referendumId: String) {
        guard let referendumDetailsView = ReferendumDetailsViewFactory.createView(for: referendumId) else {
            return
        }

        let navigationController = SoraNavigationController(rootViewController: referendumDetailsView.controller)

        view?.controller.present(navigationController,
                                 animated: true,
                                 completion: nil)
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
