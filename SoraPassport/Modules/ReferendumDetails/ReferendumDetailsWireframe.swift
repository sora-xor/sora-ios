import Foundation

final class ReferendumDetailsWireframe: ReferendumDetailsWireframeProtocol {
    private lazy var inputTransitioningHandler = ActionPresentationFactory()

    func showVotingView(from view: ReferendumDetailsViewProtocol?,
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

    func close(view: ReferendumDetailsViewProtocol?) {
        view?.controller.navigationController?
            .presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func showVotesHistoryView(from view: ReferendumDetailsViewProtocol?) {
        guard let votesHistoryView = VotesHistoryViewFactory.createView() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            votesHistoryView.controller.hidesBottomBarWhenPushed = true
            navigationController.pushViewController(votesHistoryView.controller, animated: true)
        }
    }
}
