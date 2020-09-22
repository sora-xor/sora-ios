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
    case waitingCacheProjects
    case waitingCacheReferendums
    case loading
    case loadingProjects
    case loadingReferendums
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

    func setup(projectLayoutMetadata: ProjectLayoutMetadata,
               referendumLayoutMetadata: ReferendumLayoutMetadata)

    func viewDidAppear()
    func activateProjectDisplay(type: ProjectDisplayType)
    func activateProject(at index: Int)
    func activateVotesDetails()
    func activateHelp()

    var numberOfProjects: Int { get }
    func viewModel(at index: Int) -> VotingOneOfViewModel
}

protocol ProjectsInteractorInputProtocol: class {
    func setup()
	func refreshVotes()
    func vote(for project: ProjectVote)
    func vote(for referendum: ReferendumVote)
    func toggleFavorite(for projectId: String)
}

protocol ProjectsInteractorOutputProtocol: class {
    func didReceive(votes: VotesData)
    func didReceiveVotesDataProvider(error: Error)

    func didVote(for project: ProjectVote)
    func didReceiveVote(error: Error, for project: ProjectVote)

    func didVote(for referendum: ReferendumVote)
    func didReceiveVote(error: Error, for referendum: ReferendumVote)

    func didToggleFavorite(for projectId: String)
    func didReceiveTogglingFavorite(error: Error, for projectId: String)
}

protocol ProjectsListPresenterDelegate: class {
    func didSelectVoting(for project: ProjectData, in projectsList: ProjectsListPresenterProtocol) -> Bool

    func didSelectVoting(for referendum: ReferendumData,
                         option: ReferendumVotingCase,
                         in projectsList: ProjectsListPresenterProtocol) -> Bool

    func didElapsedTime(for referendum: ReferendumData, in projectList: ProjectsListPresenterProtocol)

    func didToggleFavorite(for project: ProjectData, in projectsList: ProjectsListPresenterProtocol) -> Bool
}

protocol ProjectsListPresenterProtocol: class {
    var view: ProjectsListViewProtocol? { get set }
    var loadingState: ProjectDataLoadingState { get }

    func setup(projectLayoutMetadata: ProjectLayoutMetadata,
               referendumLayoutMetadata: ReferendumLayoutMetadata)

    func refresh()
    func setFavorite(value: Bool, for projectId: String)

    var numberOfProjects: Int { get }
    func viewModel(at index: Int) -> VotingOneOfViewModel
}

protocol ProjectsListInteractorInputProtocol: class {
    func setup()
    func refresh()
}

protocol ProjectsListInteractorOutputProtocol: class {
    func didReceiveProjects(changes: [DataProviderChange<ProjectData>])
    func didReceiveProjectsDataProvider(error: Error)

    func didReceiveReferendums(changes: [DataProviderChange<ReferendumData>])
    func didReceiveReferendumsDataProvider(error: Error)

    func didViewProject(with projectId: String)
}

protocol ProjectsWireframeProtocol: AlertPresentable, ErrorPresentable, HelpPresentable {
    func showVotingView(from view: ProjectsViewProtocol?,
                        with model: VoteViewModelProtocol,
                        style: VoteViewStyle,
                        delegate: VoteViewDelegate?)

    func showProjectDetails(from view: ProjectsViewProtocol?,
                            projectId: String)

    func showReferendumDetails(from view: ProjectsViewProtocol?,
                               referendumId: String)

    func showVotingHistory(from view: ProjectsViewProtocol?)
}

protocol ProjectsViewFactoryProtocol: class {
	static func createView() -> ProjectsViewProtocol?
}
