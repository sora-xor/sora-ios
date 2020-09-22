/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

private typealias PendingProjectFavorite = (value: Bool, displayType: ProjectDisplayType)
private typealias PendingProjectVote = (value: String, displayType: ProjectDisplayType)

final class ProjectsPresenter {
	weak var view: ProjectsViewProtocol?
	var interactor: ProjectsInteractorInputProtocol!
	var wireframe: ProjectsWireframeProtocol!

    private(set) var children: [ProjectDisplayType: ProjectsListPresenterProtocol]

    private(set) var voteViewModelFactory: VoteViewModelFactoryProtocol
    private(set) var votesDisplayFormatter: LocalizableResource<NumberFormatter>

    private(set) var displayType = ProjectDisplayType.all

    private var votes: VotesData?

    private var pendingFavoriteStore: [String: PendingProjectFavorite] = [:]

    var logger: LoggerProtocol?

    init(children: [ProjectDisplayType: ProjectsListPresenterProtocol],
         voteViewModelFactory: VoteViewModelFactoryProtocol,
         votesDisplayFormatter: LocalizableResource<NumberFormatter>) {
        self.children = children
        self.voteViewModelFactory = voteViewModelFactory
        self.votesDisplayFormatter = votesDisplayFormatter
    }

    private func refreshProjects() {
        children.forEach { (_, child) in
            child.refresh()
        }
    }

    private func updateVotesView() {
        if let votes = votes {
            let displayVotes: String

            let locale = localizationManager?.selectedLocale ?? Locale.current

            if let votesValue = Decimal(string: votes.value),
                let votesString = votesDisplayFormatter.value(for: locale)
                    .string(from: (votesValue as NSNumber)) {
                displayVotes =  votesString
            } else {
                displayVotes = ""
            }

            view?.didLoad(votes: displayVotes)
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

        if childPresenter.loadingState == .loaded {
            return childPresenter.numberOfProjects == 0
        } else {
            return false
        }
    }

    func setup(projectLayoutMetadata: ProjectLayoutMetadata,
               referendumLayoutMetadata: ReferendumLayoutMetadata) {
        children[displayType]?.view = view

        interactor.setup()

        children.forEach { $0.value.setup(projectLayoutMetadata: projectLayoutMetadata,
                                          referendumLayoutMetadata: referendumLayoutMetadata) }
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

        let viewModel = child.viewModel(at: index)

        switch viewModel {
        case .project:
            wireframe.showProjectDetails(from: view, projectId: viewModel.identifier)
        case .referendum:
            wireframe.showReferendumDetails(from: view, referendumId: viewModel.identifier)
        }
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

    func viewModel(at index: Int) -> VotingOneOfViewModel {
        return children[displayType]!.viewModel(at: index)
    }
}

extension ProjectsPresenter: ProjectsInteractorOutputProtocol {
    func didReceive(votes: VotesData) {
        self.votes = votes
        updateVotesView()
    }

    func didReceiveVotesDataProvider(error: Error) {
        logger?.debug("Did receive votes provider error: \(error)")
    }

    func didVote(for project: ProjectVote) {
        refreshProjects()

        interactor.refreshVotes()
    }

    func didReceiveVote(error: Error, for project: ProjectVote) {
        if wireframe.present(error: error, from: view, locale: localizationManager?.selectedLocale) {
            return
        }

        if let votingError = error as? VoteDataError {
            let languages = localizationManager?.preferredLocalizations

            switch votingError {
            case .votesNotEnough:
                wireframe.present(message: R.string.localizable
                                    .votesNotEnoughErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)
            case .projectNotFound:
                wireframe.present(message: R.string.localizable
                    .votesProjectNotFoundErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)

                refreshProjects()
            case .votingNotAllowed:
                wireframe.present(message: R.string.localizable
                                    .votesNotAllowedErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)
            case .incorrectVotesFormat:
                wireframe.present(message: R.string.localizable
                                    .votesInvalidFormatErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)
            }
        }
    }

    func didVote(for referendum: ReferendumVote) {
        refreshProjects()

        interactor.refreshVotes()
    }

    func didReceiveVote(error: Error, for referendum: ReferendumVote) {
        let locale = localizationManager?.selectedLocale

        if wireframe.present(error: error, from: view, locale: locale) {
            return
        }

        if let votingError = error as? ReferendumVoteDataError {
            let languages = localizationManager?.preferredLocalizations
            switch votingError {
            case .votesNotEnough:
                wireframe.present(message: R.string.localizable
                                    .votesNotEnoughErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)
            case .referendumNotFound:
                wireframe.present(message: R.string.localizable
                                    .votesProjectNotFoundErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)

                refreshProjects()
            case .votingNotAllowed:
                wireframe.present(message: R.string.localizable
                                    .votesNotAllowedErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)
            case .userNotFound:
                wireframe.present(message: R.string.localizable
                                    .registrationUserNotFoundMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
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

        if wireframe.present(error: error, from: view, locale: localizationManager?.selectedLocale) {
            return
        }

        if let togglingFavoriteError = error as? ProjectFavoriteToggleDataError {
            let languages = localizationManager?.preferredLocalizations

            switch togglingFavoriteError {
            case .projectNotFound:
                wireframe.present(message: R.string.localizable
                    .favoriteProjectNotFoundErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                                  from: view)
            case .userNotFound:
                wireframe.present(message: R.string.localizable
                    .favoriteUserNotFoundErrorMessage(preferredLanguages: languages),
                                  title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                                  closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
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
            let locale = localizationManager?.selectedLocale ?? Locale.current
            let viewModel = try voteViewModelFactory.createViewModel(with: project,
                                                                     votes: votes,
                                                                     locale: locale)
            let style = VoteViewStyle.projectStyle(for: locale)
            wireframe.showVotingView(from: view,
                                     with: viewModel,
                                     style: style,
                                     delegate: self)

            return true
        } catch VoteViewModelFactoryError.notEnoughVotes {
            let languages = localizationManager?.preferredLocalizations
            wireframe.present(message: R.string.localizable
                .votesZeroErrorMessage(preferredLanguages: languages),
                              title: "",
                              closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                              from: view)

            interactor.refreshVotes()

            return false
        } catch VoteViewModelFactoryError.noVotesNeeded {
            let languages = localizationManager?.preferredLocalizations
            wireframe.present(message: R.string.localizable
                .votesNotAllowedErrorMessage(preferredLanguages: languages),
                              title: "",
                              closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                              from: view)

            return false
        } catch {
            let languages = localizationManager?.preferredLocalizations
            wireframe.present(message: R.string.localizable
                .votesProjectParametersErrorMessage(preferredLanguages: languages),
                              title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                              closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                              from: view)

            return false
        }
    }

    func didSelectVoting(for referendum: ReferendumData,
                         option: ReferendumVotingCase,
                         in projectsList: ProjectsListPresenterProtocol) -> Bool {
        guard let votes = votes else {
            return false
        }

        do {
            let locale = localizationManager?.selectedLocale ?? Locale.current
            let viewModel = try voteViewModelFactory.createViewModel(with: referendum,
                                                                     option: option,
                                                                     votes: votes,
                                                                     locale: locale)
            let style = VoteViewStyle.referendumStyle(for: option, locale: locale)
            wireframe.showVotingView(from: view,
                                     with: viewModel,
                                     style: style,
                                     delegate: self)

            return true
        } catch VoteViewModelFactoryError.notEnoughVotes {
            let languages = localizationManager?.preferredLocalizations
            wireframe.present(message: R.string.localizable
                .votesZeroErrorMessage(preferredLanguages: languages),
                              title: "",
                              closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                              from: view)

            interactor.refreshVotes()

            return false
        } catch VoteViewModelFactoryError.noVotesNeeded {
            let languages = localizationManager?.preferredLocalizations
            wireframe.present(message: R.string.localizable
                .votesNotAllowedErrorMessage(preferredLanguages: languages),
                              title: "",
                              closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                              from: view)

            return false
        } catch {
            let languages = localizationManager?.preferredLocalizations
            wireframe.present(message: R.string.localizable
                .votesProjectParametersErrorMessage(preferredLanguages: languages),
                              title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages),
                              closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
                              from: view)

            return false
        }
    }

    func didElapsedTime(for referendum: ReferendumData, in projectList: ProjectsListPresenterProtocol) {
        refreshProjects()
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

        guard let target = view.model?.target else {
            return
        }

        let votes = amount.rounded(mode: .plain).stringWithPointSeparator

        switch target {
        case .project(let identifier):
            let projectVote = ProjectVote(projectId: identifier, votes: votes)
            interactor.vote(for: projectVote)
        case .referendum(let identifier, let option):
            let referendumVote = ReferendumVote(referendumId: identifier,
                                                votes: votes,
                                                votingCase: option)
            interactor.vote(for: referendumVote)
        }
    }

    func didCancel(on view: VoteView) {
        logger?.debug("Did cancel voting")
    }
}

extension ProjectsPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateVotesView()
        }
    }
}
