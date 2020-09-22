/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class ProjectsInteractor {
	weak var presenter: ProjectsInteractorOutputProtocol?

    let customerDataProviderFacade: CustomerDataProviderFacadeProtocol
    let projectService: ProjectUnitServiceProtocol
    let eventCenter: EventCenterProtocol

    init(customerDataProviderFacade: CustomerDataProviderFacadeProtocol,
         projectService: ProjectUnitServiceProtocol,
         eventCenter: EventCenterProtocol) {

        self.customerDataProviderFacade = customerDataProviderFacade
        self.projectService = projectService
        self.eventCenter = eventCenter
    }

    private func setupVotesDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<VotesData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let votes):
                    self?.presenter?.didReceive(votes: votes)
                case .update(let votes):
                    self?.presenter?.didReceive(votes: votes)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveVotesDataProvider(error: error)
        }

        customerDataProviderFacade.votesProvider.addObserver(self,
                                                             deliverOn: .main,
                                                             executing: changesBlock,
                                                             failing: failBlock)
    }

    private func setupEventCenter() {
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension ProjectsInteractor: ProjectsInteractorInputProtocol {
    func setup() {
        setupEventCenter()
        setupVotesDataProvider()
    }

    func refreshVotes() {
        customerDataProviderFacade.votesProvider.refresh()
    }

    func vote(for project: ProjectVote) {
        do {
            _ = try projectService.vote(with: project, runCompletionIn: .main) { (optionalResult) in
                if let result = optionalResult {
                    switch result {
                    case .success:
                        self.eventCenter.notify(with: ProjectVoteEvent(details: project))
                    case .failure(let error):
                        self.presenter?.didReceiveVote(error: error, for: project)
                    }
                }
            }
        } catch {
            presenter?.didReceiveVote(error: error, for: project)
        }
    }

    func vote(for referendum: ReferendumVote) {
        do {
            _ = try projectService.vote(with: referendum, runCompletionIn: .main) { (optionalResult) in
                if let result = optionalResult {
                    switch result {
                    case .success:
                        self.eventCenter.notify(with: ReferendumVoteEvent(vote: referendum))
                    case .failure(let error):
                        self.presenter?.didReceiveVote(error: error, for: referendum)
                    }
                }
            }
        } catch {
            presenter?.didReceiveVote(error: error, for: referendum)
        }
    }

    func toggleFavorite(for projectId: String) {
        do {
            _ = try projectService.toggleFavorite(projectId: projectId, runCompletionIn: .main) { (optionalResult) in
                if let result = optionalResult {
                    switch result {
                    case .success:
                        self.eventCenter.notify(with: ProjectFavoriteToggleEvent(projectId: projectId))
                    case .failure(let error):
                        self.presenter?.didReceiveTogglingFavorite(error: error, for: projectId)
                    }
                }
            }
        } catch {
            presenter?.didReceiveTogglingFavorite(error: error, for: projectId)
        }
    }
}

extension ProjectsInteractor: EventVisitorProtocol {
    func processProjectVote(event: ProjectVoteEvent) {
        presenter?.didVote(for: event.details)
    }

    func processProjectFavoriteToggle(event: ProjectFavoriteToggleEvent) {
        presenter?.didToggleFavorite(for: event.projectId)
    }

    func processReferendumVote(event: ReferendumVoteEvent) {
        presenter?.didVote(for: event.vote)
    }
}
