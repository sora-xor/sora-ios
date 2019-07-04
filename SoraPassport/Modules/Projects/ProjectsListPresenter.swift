/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

final class ProjectsListPresenter {
    var view: ProjectsListViewProtocol?
    var interactor: ProjectsListInteractorInputProtocol!
    weak var delegate: ProjectsListPresenterDelegate?

    private(set) var layoutMetadata: ProjectLayoutMetadata?

    private(set) var viewModelFactory: ProjectViewModelFactoryProtocol
    private var viewModels: [ProjectOneOfViewModel] = []

    private(set) var loadingState: ProjectDataLoadingState = .waitingCache

    private var projectsDiffCalculator: ListDifferenceCalculator<ProjectData> = {
        let sortBlock: (ProjectData, ProjectData) -> Bool = { $0.fundingDeadline < $1.fundingDeadline }
        return ListDifferenceCalculator<ProjectData>(initialItems: [], sortBlock: sortBlock)
    }()

    var logger: LoggerProtocol?

    init(viewModelFactory: ProjectViewModelFactoryProtocol) {
        self.viewModelFactory = viewModelFactory
    }

    private func applyModelChanges() {
        guard let layoutMetadata = layoutMetadata else {
            return
        }

        let changes: () -> ViewModelUpdateResult = {
            let diffs: [ListDifference<ProjectData>] = self.projectsDiffCalculator.lastDifferences

            var updatedIndexes: [Int] = []
            var deletedIndexes: [Int] = []
            var insertedIndexes: [Int] = []

            for diff in diffs {
                switch diff {
                case .update(let index, _, let new):
                    let viewModel = self.viewModelFactory.create(from: new,
                                                                 layoutMetadata: layoutMetadata,
                                                                 delegate: self)
                    self.viewModels[index] = viewModel
                    updatedIndexes.append(index)
                case .delete(let index, let old):
                    self.viewModels.removeAll { $0.identifier == old.identifier }
                    deletedIndexes.append(index)
                case .insert(let index, let new):
                    let viewModel = self.viewModelFactory.create(from: new,
                                                                 layoutMetadata: layoutMetadata,
                                                                 delegate: self)
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
        guard let layoutMetadata = layoutMetadata else {
            return
        }

        let changes: () -> Void = {
            self.viewModels = self.projectsDiffCalculator.allItems.map {
                self.viewModelFactory.create(from: $0,
                                             layoutMetadata: layoutMetadata,
                                             delegate: self)
            }
        }

        if let currentView = view {
            currentView.didReloadProjects(using: changes)
        } else {
            changes()
        }
    }
}

extension ProjectsListPresenter: ProjectsListPresenterProtocol {
    func setup(layoutMetadata: ProjectLayoutMetadata) {
        self.layoutMetadata = layoutMetadata

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

        guard var project = optionalProject  else {
            refresh()
            return
        }

        project.favorite = value

        projectsDiffCalculator.apply(changes: [DataProviderChange.update(newItem: project)])
        applyModelChanges()
    }

    var numberOfProjects: Int {
        return viewModels.count
    }

    func viewModel(at index: Int) -> ProjectOneOfViewModel {
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
        guard let project = projectsDiffCalculator.allItems.first(where: { $0.identifier == modelId }) else {
            return false
        }

        guard let delegate = delegate else {
            return false
        }

        return delegate.didSelectVoting(for: project, in: self)
    }

    private func toggleFavorite(modelId: String) -> Bool {
        guard var project = projectsDiffCalculator.allItems.first(where: { $0.identifier == modelId }) else {
            return false
        }

        let optionalViewModel = viewModels.first(where: { $0.identifier == modelId })
        guard var currentViewModel = optionalViewModel else {
            return false
        }

        guard let delegate = delegate else {
            return false
        }

        if delegate.didToggleFavorite(for: project, in: self) {
            project.favorite = !project.favorite
            projectsDiffCalculator.apply(changes: [DataProviderChange.update(newItem: project)])

            currentViewModel.isFavorite = project.favorite

            return true
        } else {
            return false
        }
    }
}

extension ProjectsListPresenter: ProjectsListInteractorOutputProtocol {
    func didReceiveProjects(changes: [DataProviderChange<ProjectData>], at page: UInt) {
        switch loadingState {
        case .waitingCache:
            loadingState = .loading
            interactor.refresh()
        case .loading:
            loadingState = .loaded
        case .loaded:
            logger?.debug("Unexpected projects refresh")
        }

        projectsDiffCalculator.apply(changes: changes)

        applyModelChanges()
    }

    func didReceiveProjectsDataProvider(error: Error) {
        switch loadingState {
        case .waitingCache:
            logger?.error("Did receive unexpected projects data provider: \(error)")
        case .loading:
            loadingState = .loaded
            logger?.debug("Did receive project data provider error: \(error)")
        case .loaded:
            logger?.debug("Did receive project data provider error: \(error)")
        }
    }
}
