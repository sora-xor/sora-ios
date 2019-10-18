/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class ProjectDetailsInteractor {
	weak var presenter: ProjectDetailsInteractorOutputProtocol?

    let customerDataProviderFacade: CustomerDataProviderFacadeProtocol
    let projectDetailsDataProvider: SingleValueProvider<ProjectDetailsData, CDSingleValue>
    let projectService: ProjectUnitServiceProtocol
    let eventCenter: EventCenterProtocol

    init(customerDataProviderFacade: CustomerDataProviderFacadeProtocol,
         projectDetailsDataProvider: SingleValueProvider<ProjectDetailsData, CDSingleValue>,
         projectService: ProjectUnitServiceProtocol,
         eventCenter: EventCenterProtocol) {
        self.customerDataProviderFacade = customerDataProviderFacade
        self.projectDetailsDataProvider = projectDetailsDataProvider
        self.projectService = projectService
        self.eventCenter = eventCenter
    }

    private func setupVotesDataProvider() {
        let changesBlock: ([DataProviderChange<VotesData>]) -> Void = { [weak self] (changes) in
            if let change = changes.first {
                switch change {
                case .insert(let votes):
                    self?.presenter?.didReceive(votes: votes)
                case .update(let votes):
                    self?.presenter?.didReceive(votes: votes)
                case .delete:
                    self?.presenter?.didReceive(projectDetails: nil)
                }
            }
        }

        let failBlock: (Error) -> Void = { [weak self] (error) in
            self?.presenter?.didReceiveVotesDataProvider(error: error)
        }

        customerDataProviderFacade.votesProvider.addCacheObserver(self,
                                                                  deliverOn: .main,
                                                                  executing: changesBlock,
                                                                  failing: failBlock)
    }

    private func setupProjectDetailsProvider() {
        let changesBlock: ([DataProviderChange<ProjectDetailsData>]) -> Void = { [weak self] (changes) in
            if let change = changes.first {
                switch change {
                case .insert(let projectDetails):
                    self?.presenter?.didReceive(projectDetails: projectDetails)
                case .update(let projectDetails):
                    self?.presenter?.didReceive(projectDetails: projectDetails)
                case .delete:
                    break
                }
            }
        }

        let failBlock: (Error) -> Void = { [weak self] (error) in
            self?.presenter?.didReceiveVotesDataProvider(error: error)
        }

        projectDetailsDataProvider.addCacheObserver(self,
                                                    deliverOn: .main,
                                                    executing: changesBlock,
                                                    failing: failBlock)
    }

    func setupEventCenter() {
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension ProjectDetailsInteractor: ProjectDetailsInteractorInputProtocol {
    func setup() {
        setupEventCenter()
        setupVotesDataProvider()
        setupProjectDetailsProvider()
    }

    func vote(for project: ProjectVote) {
        do {
            _ = try projectService.vote(with: project, runCompletionIn: .main) { (optionalResult) in
                if let result = optionalResult {
                    switch result {
                    case .success:
                        self.eventCenter.notify(with: ProjectVoteEvent(details: project))
                    case .error(let error):
                        self.presenter?.didReceiveVote(error: error, for: project)
                    }
                }
            }
        } catch {
            presenter?.didReceiveVote(error: error, for: project)
        }
    }

    func refreshVotes() {
        customerDataProviderFacade.votesProvider.refreshCache()
    }

    func refreshProjectDetails() {
        projectDetailsDataProvider.refreshCache()
    }

    func toggleFavorite(for projectId: String) {
        do {
            _ = try projectService.toggleFavorite(projectId: projectId, runCompletionIn: .main) { (optionalResult) in
                if let result = optionalResult {
                    switch result {
                    case .success:
                        self.eventCenter.notify(with: ProjectFavoriteToggleEvent(projectId: projectId))
                    case .error(let error):
                        self.presenter?.didReceiveToggleFavorite(error: error, for: projectId)
                    }
                }
            }
        } catch {
            presenter?.didReceiveToggleFavorite(error: error, for: projectId)
        }
    }

    func markAsViewed(for projectId: String) {
        eventCenter.notify(with: ProjectViewEvent(projectId: projectId))
    }
}

extension ProjectDetailsInteractor: EventVisitorProtocol {
    func processProjectVote(event: ProjectVoteEvent) {
        presenter?.didVote(for: event.details)
    }

    func processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent) {
        presenter?.didToggleFavorite(for: event.projectId)
    }
}
