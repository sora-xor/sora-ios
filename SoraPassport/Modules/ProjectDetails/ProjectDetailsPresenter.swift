/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class ProjectDetailsPresenter {
	weak var view: ProjectDetailsViewProtocol?
	var interactor: ProjectDetailsInteractorInputProtocol!
	var wireframe: ProjectDetailsWireframeProtocol!

    var logger: LoggerProtocol?

    private(set) var projectDetailsViewModelFactory: ProjectViewModelFactoryProtocol
    private(set) var voteViewModelFactory: VoteViewModelFactoryProtocol
    private(set) var votesDisplayFormatter: NumberFormatter

    private(set) var votes: VotesData?
    private(set) var projectDetails: ProjectDetailsData?

    private(set) var projectDetailsViewModel: ProjectDetailsViewModel?

    private var pendingFavoriteValue: Bool?

    init(projectDetailsViewModelFactory: ProjectViewModelFactoryProtocol,
         voteViewModelFactory: VoteViewModelFactoryProtocol,
         votesDisplayFormatter: NumberFormatter) {
        self.projectDetailsViewModelFactory = projectDetailsViewModelFactory
        self.voteViewModelFactory = voteViewModelFactory
        self.votesDisplayFormatter = votesDisplayFormatter
    }

    private func applyVotes() {
        if let votes = votes {
            let votesViewModel: String

            if let votes = Decimal(string: votes.value),
               let votesString = votesDisplayFormatter.string(from: votes as NSNumber) {
                votesViewModel = votesString
            } else {
                votesViewModel = ""
            }

            view?.didReceive(votes: votesViewModel)
        }
    }

    private func applyProjectDetails() {
        if let projectDetails = projectDetails {
            let projectDetailsViewModel = projectDetailsViewModelFactory.create(from: projectDetails,
                                                                                delegate: self)

            self.projectDetailsViewModel = projectDetailsViewModel
            view?.didReceive(projectDetails: projectDetailsViewModel)
        }
    }

    private func pushPendingFavorite(newValue: Bool) -> Bool {
        guard pendingFavoriteValue == nil else {
            return false
        }

        guard let viewModel = projectDetailsViewModel else {
            return false
        }

        guard var currentProjectDetails = projectDetails else {
            return false
        }

        pendingFavoriteValue = currentProjectDetails.favorite
        currentProjectDetails.favorite = newValue
        viewModel.isFavorite = newValue

        return true
    }

    @discardableResult
    private func restorePendingFavorite() -> Bool {
        guard let pendingValue = pendingFavoriteValue else {
            return false
        }

        guard var projectDetails = projectDetails else {
            return false
        }

        pendingFavoriteValue = nil

        projectDetails.favorite = pendingValue

        let viewModel = projectDetailsViewModelFactory.create(from: projectDetails,
                                                              delegate: self)
        projectDetailsViewModel = viewModel
        view?.didReceive(projectDetails: viewModel)

        return true
    }

    private func dropPendingFavorite() {
        pendingFavoriteValue = nil
    }
}

extension ProjectDetailsPresenter: ProjectDetailsPresenterProtocol {
    func viewIsReady() {
        interactor.setup()
    }

    func activateVotes() {
        wireframe.showVotesHistoryView(from: view)
    }

    func activateGalleryItem(at index: Int, animatedFrom animatingView: UIView?) {
        guard let gallery = projectDetails?.gallery else {
            return
        }

        wireframe.showGallery(from: view,
                              for: gallery,
                              with: index,
                              animateFrom: animatingView)
    }

    func activateClose() {
        wireframe.close(view: view)
    }
}

extension ProjectDetailsPresenter: ProjectDetailsInteractorOutputProtocol {
    func didReceive(votes: VotesData) {
        self.votes = votes
        applyVotes()
    }

    func didReceiveVotesDataProvider(error: Error) {
        logger?.debug("Did receive votes provider error: \(error)")
    }

    func didReceive(projectDetails: ProjectDetailsData?) {
        guard let projectDetails = projectDetails else {
            wireframe.close(view: view)
            return
        }

        self.projectDetails = projectDetails

        applyProjectDetails()

        interactor.markAsViewed(for: projectDetails.identifier)
    }

    func didReceiveProjectDetailsDataProvider(error: Error) {
        logger?.debug("Did receive project details provider error: \(error)")
    }

    func didVote(for project: ProjectVote) {
        interactor.refreshVotes()
        interactor.refreshProjectDetails()
    }

    func didReceiveVote(error: Error, for project: ProjectVote) {
        if wireframe.present(error: error, from: view) {
            return
        }

        if let votingError = error as? VoteDataError {
            switch votingError {
            case .votesNotEnough:
                wireframe.present(message: R.string.localizable.votesNotEnoughErrorMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            case .projectNotFound:
                wireframe.present(message: R.string.localizable.votesProjectNotFoundErrorMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)

                interactor.refreshProjectDetails()
            case .votingNotAllowed:
                wireframe.present(message: R.string.localizable.votesNotAllowedErrorMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            case .incorrectVotesFormat:
                wireframe.present(message: R.string.localizable.votesInvalidFormatErrorMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            }
        }
    }

    func didToggleFavorite(for projectId: String) {
        dropPendingFavorite()

        interactor.refreshProjectDetails()
    }

    func didReceiveToggleFavorite(error: Error, for projectId: String) {
        restorePendingFavorite()
        interactor.refreshProjectDetails()

        if wireframe.present(error: error, from: view) {
            return
        }

        if let togglingFavoriteError = error as? ProjectFavoriteToggleDataError {
            switch togglingFavoriteError {
            case .projectNotFound:
                wireframe.present(message: R.string.localizable.favoriteProjectNotFoundErrorMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            case .userNotFound:
                wireframe.present(message: R.string.localizable.favoriteUserNotFoundErrorMessage(),
                                  title: R.string.localizable.errorTitle(),
                                  closeAction: R.string.localizable.close(),
                                  from: view)
            }
        }
    }
}

extension ProjectDetailsPresenter: ProjectDetailsViewModelDelegate {
    func vote(for model: ProjectDetailsViewModelProtocol) -> Bool {
        guard let projectDetails = projectDetails else {
            return false
        }

        guard let votes = votes else {
            return false
        }

        do {
            let viewModel = try voteViewModelFactory.createViewModel(with: projectDetails,
                                                                     votes: votes)
            wireframe.showVotingView(from: view,
                                     with: viewModel,
                                     delegate: self)

            return true
        } catch VoteViewModelFactoryError.notEnoughVotes {
            wireframe.present(message: R.string.localizable.votesZeroErrorMessage(),
                              title: "",
                              closeAction: R.string.localizable.close(),
                              from: view)

            interactor.refreshVotes()

            return false
        } catch VoteViewModelFactoryError.noVotesNeeded {
            wireframe.present(message: R.string.localizable.votesNotAllowedErrorMessage(),
                              title: "",
                              closeAction: R.string.localizable.close(),
                              from: view)

            return false
        } catch {
            wireframe.present(message: R.string.localizable.votesProjectParametersErrorMessage(),
                              title: R.string.localizable.errorTitle(),
                              closeAction: R.string.localizable.close(),
                              from: view)

            return false
        }
    }

    func toggleFavorite(for model: ProjectDetailsViewModelProtocol) -> Bool {
        guard let currentProjectDetails = projectDetails else {
            return false
        }

        guard pushPendingFavorite(newValue: !model.isFavorite) else {
            return false
        }

        interactor.toggleFavorite(for: currentProjectDetails.identifier)

        return true
    }

    func openWebsite(for model: ProjectDetailsViewModelProtocol) {
        guard let projectUrl = projectDetails?.link else {
            return
        }

        guard let view = view else {
            return
        }

        wireframe.showWeb(url: projectUrl,
                          from: view,
                          style: .modal)
    }

    func writeEmail(for model: ProjectDetailsViewModelProtocol) {
        guard let view = view  else {
            return
        }

        guard model.email.count > 0 else {
            return
        }

        let message = SocialMessage {
            $0.subject = R.string.localizable.projectDetailsEmailSubject()
            $0.recepients = [model.email]
        }

        wireframe.writeEmail(with: message,
                             from: view,
                             completionHandler: nil)
    }
}

extension ProjectDetailsPresenter: VoteViewDelegate {
    func didVote(on view: VoteView, amount: Decimal) {
        view.presenter?.hide(view: view, animated: true)

        guard let projectId = view.model?.projectId else {
            return
        }

        let votes = amount.rounded(mode: .plain).stringWithPointSeparator
        let projectVote = ProjectVote(projectId: projectId, votes: votes)

        interactor.vote(for: projectVote)
    }

    func didCancel(on view: VoteView) {
        logger?.debug("Did cancel voting")
    }
}
