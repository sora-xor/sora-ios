/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood
import SoraUI

enum ProjectDisplayType: Int {
    case all = 0
    case voted = 1
    case favorite = 2
    case completed = 3
}

enum ProjectDataLoadingState {
    case waitingCache
    case loading
    case loaded
}

typealias ViewModelUpdateResult = (updatedIndexes: [Int], deletedIndexes: [Int], insertedIndexes: [Int])

protocol ProjectsListViewProtocol: ControllerBackedProtocol {
    func didReloadProjects(using viewModelChangeBlock: @escaping () -> Void)
    func didEditProjects(using viewModelChangeBlock: @escaping () -> ViewModelUpdateResult)
}

protocol ProjectsViewProtocol: ProjectsListViewProtocol {
    func didLoad(votes: String)
}

protocol ProjectsPresenterProtocol: EmptyStateDelegate {
    var displayType: ProjectDisplayType { get }

    func setup(layoutMetadata: ProjectLayoutMetadata)
    func viewDidAppear()
    func activateProjectDisplay(type: ProjectDisplayType)
    func activateProject(at index: Int)
    func activateVotesDetails()
    func activateHelp()

    var numberOfProjects: Int { get }
    func viewModel(at index: Int) -> ProjectOneOfViewModel
}

protocol ProjectsInteractorInputProtocol: class {
    func setup()
	func refreshVotes()
    func vote(for project: ProjectVote)
    func toggleFavorite(for projectId: String)
}

protocol ProjectsInteractorOutputProtocol: class {
    func didReceive(votes: VotesData)
    func didReceiveVotesDataProvider(error: Error)

    func didVote(for project: ProjectVote)
    func didReceiveVote(error: Error, for project: ProjectVote)

    func didToggleFavorite(for projectId: String)
    func didReceiveTogglingFavorite(error: Error, for projectId: String)
}

protocol ProjectsListPresenterDelegate: class {
    func didSelectVoting(for project: ProjectData, in projectsList: ProjectsListPresenterProtocol) -> Bool
    func didToggleFavorite(for project: ProjectData, in projectsList: ProjectsListPresenterProtocol) -> Bool
}

protocol ProjectsListPresenterProtocol: class {
    var view: ProjectsListViewProtocol? { get set }
    var loadingState: ProjectDataLoadingState { get }

    func setup(layoutMetadata: ProjectLayoutMetadata)
    func refresh()
    func setFavorite(value: Bool, for projectId: String)

    var numberOfProjects: Int { get }
    func viewModel(at index: Int) -> ProjectOneOfViewModel
}

protocol ProjectsListInteractorInputProtocol: class {
    func setup()
    func refresh()
}

protocol ProjectsListInteractorOutputProtocol: class {
    func didReceiveProjects(changes: [DataProviderChange<ProjectData>], at page: UInt)
    func didReceiveProjectsDataProvider(error: Error)

    func didViewProject(with projectId: String)
}

protocol ProjectsWireframeProtocol: AlertPresentable, ErrorPresentable, HelpPresentable {
    func showVotingView(from view: ProjectsViewProtocol?,
                        with model: VoteViewModelProtocol,
                        delegate: VoteViewDelegate?)

    func showProjectDetails(from view: ProjectsViewProtocol?,
                            projectId: String)

    func showVotingHistory(from view: ProjectsViewProtocol?)
}

protocol ProjectsViewFactoryProtocol: class {
	static func createView() -> ProjectsViewProtocol?
}
