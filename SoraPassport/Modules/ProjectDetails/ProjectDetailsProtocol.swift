/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol ProjectDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(votes: String)
    func didReceive(projectDetails: ProjectDetailsViewModelProtocol)
}

protocol ProjectDetailsPresenterProtocol: class {
	func viewIsReady()
    func activateVotes()
    func activateGalleryItem(at index: Int, animatedFrom animatingView: UIView?)
    func activateClose()
}

protocol ProjectDetailsInteractorInputProtocol: class {
    func setup()
    func refreshVotes()
    func refreshProjectDetails()
    func vote(for project: ProjectVote)
    func toggleFavorite(for projectId: String)
    func markAsViewed(for projectId: String)
}

protocol ProjectDetailsInteractorOutputProtocol: class {
    func didReceive(votes: VotesData)
    func didReceiveVotesDataProvider(error: Error)

    func didReceive(projectDetails: ProjectDetailsData?)
    func didReceiveProjectDetailsDataProvider(error: Error)

    func didVote(for project: ProjectVote)
    func didReceiveVote(error: Error, for project: ProjectVote)

    func didToggleFavorite(for projectId: String)
    func didReceiveToggleFavorite(error: Error, for projectId: String)
}

protocol ProjectDetailsWireframeProtocol: AlertPresentable, ErrorPresentable,
WebPresentable, EmailPresentable, MediaGalleryPresentable, OutboundUrlPresentable {
    func showVotingView(from view: ProjectDetailsViewProtocol?,
                        with model: VoteViewModelProtocol,
                        delegate: VoteViewDelegate?)

    func close(view: ProjectDetailsViewProtocol?)

    func showVotesHistoryView(from view: ProjectDetailsViewProtocol?)
}

protocol ProjectDetailsViewFactoryProtocol: class {
    static func createView(for projectId: String) -> ProjectDetailsViewProtocol?
}
