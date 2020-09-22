import Foundation
import RobinHood
import SoraFoundation

final class ProjectsListPresenter {
    weak var view: ProjectsListViewProtocol?
    var interactor: ProjectsListInteractorInputProtocol!
    weak var delegate: ProjectsListPresenterDelegate?

    private(set) var projectLayoutMetadata: ProjectLayoutMetadata!
    private(set) var referendumLayoutMetadata: ReferendumLayoutMetadata!

    private(set) var projectsViewModelFactory: ProjectViewModelFactoryProtocol
    private(set) var referendumViewModelFactory: ReferendumViewModelFactoryProtocol
    private var viewModels: [VotingOneOfViewModel] = []

    private(set) var loadingState: ProjectDataLoadingState = .waitingCache

    private var projectsDiffCalculator: ListDifferenceCalculator<VotingListModel> = {
        let sortBlock: (VotingListModel, VotingListModel) -> Bool = {
            return $0.statusUpdateTime > $1.statusUpdateTime
        }
        return ListDifferenceCalculator(initialItems: [], sortBlock: sortBlock)
    }()

    var logger: LoggerProtocol?

    init(projectsViewModelFactory: ProjectViewModelFactoryProtocol,
         referendumViewModelFactory: ReferendumViewModelFactoryProtocol) {
        self.projectsViewModelFactory = projectsViewModelFactory
        self.referendumViewModelFactory = referendumViewModelFactory
    }

    private func applyModelChanges() {
        let changes: () -> ViewModelUpdateResult = {
            let diffs: [ListDifference<VotingListModel>] = self.projectsDiffCalculator.lastDifferences

            var updatedIndexes: [Int] = []
            var deletedIndexes: [Int] = []
            var insertedIndexes: [Int] = []

            for diff in diffs {
                switch diff {
                case .update(let index, _, let new):
                    let viewModel = self.buildViewModel(new)
                    self.viewModels[index] = viewModel
                    updatedIndexes.append(index)
                case .delete(let index, let old):
                    self.viewModels.removeAll { $0.identifier == old.identifier }
                    deletedIndexes.append(index)
                case .insert(let index, let new):
                    let viewModel = self.buildViewModel(new)
                    self.viewModels.insert(viewModel, at: index)
                    insertedIndexes.append(index)
                }
            }

            return ViewModelUpdateResult(updatedIndexes: updatedIndexes,
                                         deletedIndexes: deletedIndexes,
                                         insertedIndexes: insertedIndexes)
        }

        if let currentView = view {
            currentView.didEditProjects(using: changes)
        } else {
            _ = changes()
        }
    }

    private func reloadModel() {
        let changes: () -> Void = {
            self.viewModels = self.projectsDiffCalculator.allItems.map {
                self.buildViewModel($0)
            }
        }

        if let currentView = view {
            currentView.didReloadProjects(using: changes)
        } else {
            changes()
        }
    }

    private func buildViewModel(_ model: VotingListModel) -> VotingOneOfViewModel {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        switch model {
        case .project(let project):
            let viewModel = projectsViewModelFactory.create(from: project,
                                                            layoutMetadata: projectLayoutMetadata,
                                                            delegate: self,
                                                            locale: locale)
            return .project(viewModel)
        case .referendum(let referendum):
            let viewModel = referendumViewModelFactory.create(from: referendum,
                                                              layoutMetadata: referendumLayoutMetadata,
                                                              delegate: self,
                                                              locale: locale)
            return .referendum(viewModel)
        }
    }
}

extension ProjectsListPresenter: ProjectsListPresenterProtocol {
    func setup(projectLayoutMetadata: ProjectLayoutMetadata,
               referendumLayoutMetadata: ReferendumLayoutMetadata) {
        projectsViewModelFactory.delegate = self
        referendumViewModelFactory.delegate = self

        self.projectLayoutMetadata = projectLayoutMetadata
        self.referendumLayoutMetadata = referendumLayoutMetadata

        interactor.setup()
    }

    func refresh() {
        if loadingState == .loaded {
            loadingState = .loading
            interactor.refresh()
        }
    }

    func setFavorite(value: Bool, for projectId: String) {
        let optionalProject = projectsDiffCalculator.allItems.first {
            $0.identifier == projectId
        }

        guard case .project(var item) = optionalProject  else {
            refresh()
            return
        }

        item.favorite = value

        projectsDiffCalculator.apply(changes: [DataProviderChange.update(newItem: .project(item))])
        applyModelChanges()
    }

    var numberOfProjects: Int {
        return viewModels.count
    }

    func viewModel(at index: Int) -> VotingOneOfViewModel {
        return viewModels[index]
    }
}

extension ProjectsListPresenter: ProjectViewModelDelegate {
    func vote(model: OpenProjectViewModelProtocol) -> Bool {
        return vote(modelId: model.identifier)
    }

    func toggleFavorite(model: OpenProjectViewModelProtocol) -> Bool {
        return toggleFavorite(modelId: model.identifier)
    }

    func toggleFavorite(model: FinishedProjectViewModelProtocol) -> Bool {
        return toggleFavorite(modelId: model.identifier)
    }

    private func vote(modelId: String) -> Bool {
        guard
            let votingModel = projectsDiffCalculator.allItems.first(where: { $0.identifier == modelId }),
            case .project(let project) = votingModel else {
            return false
        }

        guard let delegate = delegate else {
            return false
        }

        return delegate.didSelectVoting(for: project, in: self)
    }

    private func toggleFavorite(modelId: String) -> Bool {
        guard
            let model = projectsDiffCalculator.allItems.first(where: { $0.identifier == modelId }),
            case .project(var project) = model else {
            return false
        }

        let optionalViewModel = viewModels.first(where: { $0.identifier == modelId })
        guard let currentViewModel = optionalViewModel,
            case .project(var projectViewModel) = currentViewModel else {
            return false
        }

        guard let delegate = delegate else {
            return false
        }

        if delegate.didToggleFavorite(for: project, in: self) {
            project.favorite = !project.favorite
            projectsDiffCalculator.apply(changes: [DataProviderChange.update(newItem: .project(project))])

            projectViewModel.isFavorite = project.favorite

            return true
        } else {
            return false
        }
    }
}

extension ProjectsListPresenter: ReferendumViewModelDelegate {
    func support(referendum: ReferendumViewModelProtocol) {
        vote(viewModel: referendum, option: .support)
    }

    func unsupport(referendum: ReferendumViewModelProtocol) {
        vote(viewModel: referendum, option: .unsupport)
    }

    func handleElapsedTime(for referendum: ReferendumViewModelProtocol) {
        guard let model = projectsDiffCalculator.allItems
            .first(where: { $0.identifier == referendum.identifier }),
            case .referendum(let item) = model else {
            return
        }

        delegate?.didElapsedTime(for: item, in: self)
    }

    private func vote(viewModel: ReferendumViewModelProtocol, option: ReferendumVotingCase) {
        guard let model = projectsDiffCalculator.allItems
            .first(where: { $0.identifier == viewModel.identifier }),
            case .referendum(let item) = model else {
            return
        }

        _ = delegate?.didSelectVoting(for: item,
                                      option: option,
                                      in: self)
    }
}

extension ProjectsListPresenter: ProjectsListInteractorOutputProtocol {
    func didReceiveProjects(changes: [DataProviderChange<ProjectData>]) {
        switch loadingState {
        case .waitingCache:
            loadingState = .waitingCacheReferendums
        case .waitingCacheProjects:
            loadingState = .loading
            interactor.refresh()
        case .loading:
            loadingState = .loadingReferendums
        case .loadingProjects:
            loadingState = .loaded
        case .waitingCacheReferendums, .loadingReferendums, .loaded:
            logger?.debug("Unexpected projects refresh \(loadingState)")
        }

        let votingChanges: [DataProviderChange<VotingListModel>] = changes.map { change in
            switch change {
            case .insert(let newItem):
                return DataProviderChange.insert(newItem: .project(newItem))
            case .update(let newItem):
                return DataProviderChange.update(newItem: .project(newItem))
            case .delete(let deletedIdentifier):
                return DataProviderChange.delete(deletedIdentifier: deletedIdentifier)
            }
        }

        projectsDiffCalculator.apply(changes: votingChanges)

        applyModelChanges()
    }

    func didReceiveProjectsDataProvider(error: Error) {
        switch loadingState {
        case .waitingCache, .waitingCacheProjects:
            logger?.error("Did receive unexpected projects data provider: \(error)")
        case .waitingCacheReferendums, .loadingReferendums:
            logger?.error("Did receive unexpected projects data provider: \(error)")
        case .loading:
            loadingState = .loadingReferendums
            logger?.debug("Did receive project data provider error: \(error)")
        case .loadingProjects:
            loadingState = .loaded
            logger?.debug("Did receive project data provider error: \(error)")
        case .loaded:
            logger?.debug("Did receive project data provider error: \(error)")
        }
    }

    func didReceiveReferendums(changes: [DataProviderChange<ReferendumData>]) {
        switch loadingState {
        case .waitingCache:
            loadingState = .waitingCacheProjects
        case .waitingCacheReferendums:
            loadingState = .loading
            interactor.refresh()
        case .loading:
            loadingState = .loadingProjects
        case .loadingReferendums:
            loadingState = .loaded
        case .waitingCacheProjects, .loadingProjects, .loaded:
            logger?.debug("Unexpected projects refresh \(loadingState)")
        }

        let votingChanges: [DataProviderChange<VotingListModel>] = changes.map { change in
            switch change {
            case .insert(let newItem):
                return DataProviderChange.insert(newItem: .referendum(newItem))
            case .update(let newItem):
                return DataProviderChange.update(newItem: .referendum(newItem))
            case .delete(let deletedIdentifier):
                return DataProviderChange.delete(deletedIdentifier: deletedIdentifier)
            }
        }

        projectsDiffCalculator.apply(changes: votingChanges)

        applyModelChanges()
    }

    func didReceiveReferendumsDataProvider(error: Error) {
        switch loadingState {
        case .waitingCache, .waitingCacheReferendums:
            logger?.error("Did receive unexpected referendum data provider: \(error)")
        case .waitingCacheProjects, .loadingProjects:
            logger?.error("Did receive unexpected projects data provider: \(error)")
        case .loading:
            loadingState = .loadingProjects
        case .loadingReferendums:
            loadingState = .loaded
            logger?.debug("Did receive referendum data provider error: \(error)")
        case .loaded:
            logger?.debug("Did receive referendum data provider error: \(error)")
        }
    }

    func didViewProject(with projectId: String) {
        guard
            let model = projectsDiffCalculator.allItems.first(where: { $0.identifier == projectId }),
            case .project(let item) = model else {
            return
        }

        if item.unwatched {
            interactor.refresh()
        }
    }
}

extension ProjectsListPresenter: ProjectViewModelFactoryDelegate {
    func projectFactoryDidChange(_ factory: DynamicProjectViewModelFactoryProtocol) {
        guard let view = view else {
            return
        }

        if view.isSetup {
            reloadModel()
        }
    }
}

extension ProjectsListPresenter: Localizable {
    func applyLocalization() {
        guard let view = view else {
            return
        }

        if view.isSetup {
            reloadModel()
        }
    }
}
