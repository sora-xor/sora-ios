/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

private typealias PendingProjectFavorite = (value: Bool, displayType: ProjectDisplayType)
private typealias PendingProjectVote = (value: String, displayType: ProjectDisplayType)

final class ProjectsPresenter {
	weak var view: ProjectsViewProtocol?
	var interactor: ProjectsInteractorInputProtocol!
	var wireframe: ProjectsWireframeProtocol!

    private(set) var children: [ProjectDisplayType: ProjectsListPresenterProtocol]

    private(set) var voteViewModelFactory: VoteViewModelFactoryProtocol
    private(set) var votesDisplayFormatter: NumberFormatter

    private(set) var displayType = ProjectDisplayType.all

    private var votes: VotesData?

    private var pendingFavoriteStore: [String: PendingProjectFavorite] = [:]

    var logger: LoggerProtocol?

    init(children: [ProjectDisplayType: ProjectsListPresenterProtocol],
         voteViewModelFactory: VoteViewModelFactoryProtocol,
         votesDisplayFormatter: NumberFormatter) {
        self.children = children
        self.voteViewModelFactory = voteViewModelFactory
        self.votesDisplayFormatter = votesDisplayFormatter
    }

    private func refreshProjects() {
        children.forEach { (_, child) in
            child.refresh()
        }
    }

    // MARK: Pending favorites

    @discardableResult
    private func pushPendingFavorite(for project: ProjectData, newValue: Bool) -> Bool {
        guard pendingFavoriteStore[project.identifier] == nil else {
            return false
        }

        pendingFavoriteStore[project.identifier] = PendingProjectFavorite(value: project.favorite,
                                                                          displayType: displayType)

        return true
    }

    @discardableResult
    private func restorePendingFavorite(for projectId: String) -> Bool {
        guard let pendingFavorite = pendingFavoriteStore[projectId] else {
            return false
        }

        pendingFavoriteStore[projectId] = nil

        if let child = children[pendingFavorite.displayType] {
            child.setFavorite(value: pendingFavorite.value,
                              for: projectId)
        }

        return true
    }

    private func dropPendingFavorite(for projectId: String) {
        pendingFavoriteStore[projectId] = nil
    }
}

extension ProjectsPresenter: ProjectsPresenterProtocol {
    var shouldDisplayEmptyState: Bool {
        guard let childPresenter = children[displayType] else {
            return false
        }

        switch childPresenter.loadingState {
        case .waitingCache:
            return false
        case .loading:
            return false
        case .loaded:
            return childPresenter.numberOfProjects == 0
        }
    }

    func viewIsReady(layoutMetadata: ProjectLayoutMetadata) {
        children[displayType]?.view = view

        interactor.setup()

        children.forEach { $0.value.setup(layoutMetadata: layoutMetadata) }
    }

    func viewDidAppear() {
        refreshProjects()

        interactor.refreshVotes()
    }

    func activateProjectDisplay(type: ProjectDisplayType) {
        guard let newChild = self.children[type] else {
            return
        }

        view?.didReloadProjects {
            self.displayType = type

            if let oldChildKeyValue = self.children.first(where: { $0.value.view != nil }) {
                oldChildKeyValue.value.view = nil
            }

            newChild.view = self.view
        }
    }

    func activateProject(at index: Int) {
        guard let child = children[displayType] else {
            return
        }

        let projectViewModel = child.viewModel(at: index)

        wireframe.showProjectDetails(from: view, projectId: projectViewModel.identifier)
    }

    func activateVotesDetails() {
        wireframe.showVotingHistory(from: view)
    }

    func activateHelp() {
        wireframe.presentHelp(from: view)
    }

    var numberOfProjects: Int {
        return children[displayType]?.numberOfProjects ?? 0
    }

    func viewModel(at index: Int) -> ProjectOneOfViewModel {
        return children[displayType]!.viewModel(at: index)
    }
}

extension ProjectsPresenter: ProjectsInteractorOutputProtocol {
    func didReceive(votes: VotesData) {
        self.votes = votes
        let displayVotes: String

        if let votesValue = Decimal(string: votes.value),
            let votesString = votesDisplayFormatter.string(from: (votesValue as NSNumber)) {
            displayVotes =  votesString
        } else {
            displayVotes = ""
        }

        view?.didLoad(votes: displayVotes)
    }

    func didReceiveVotesDataProvider(error: Error) {
        logger?.debug("Did receive votes provider error: \(error)")
    }

    func didVote(for project: ProjectVote) {
        refreshProjects()

        interactor.refreshVotes()
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

                refreshProjects()
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
        dropPendingFavorite(for: projectId)

        refreshProjects()
    }

    func didReceiveTogglingFavorite(error: Error, for projectId: String) {
        restorePendingFavorite(for: projectId)

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

extension ProjectsPresenter: ProjectsListPresenterDelegate {
    func didSelectVoting(for project: ProjectData, in projectsList: ProjectsListPresenterProtocol) -> Bool {
        guard let votes = votes else {
            return false
        }

        do {
            let viewModel = try voteViewModelFactory.createViewModel(with: project,
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

    func didToggleFavorite(for project: ProjectData, in projectsList: ProjectsListPresenterProtocol) -> Bool {
        guard pushPendingFavorite(for: project, newValue: !project.favorite) else {
            return false
        }

        interactor.toggleFavorite(for: project.identifier)

        return true
    }
}

extension ProjectsPresenter: VoteViewDelegate {
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
