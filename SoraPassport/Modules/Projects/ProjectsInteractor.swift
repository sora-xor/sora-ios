/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

final class ProjectsInteractor {
	weak var presenter: ProjectsInteractorOutputProtocol?

    private(set) var customerDataProviderFacade: CustomerDataProviderFacadeProtocol
    private(set) var projectService: ProjectUnitServiceProtocol

    init(customerDataProviderFacade: CustomerDataProviderFacadeProtocol,
         projectService: ProjectUnitServiceProtocol) {

        self.customerDataProviderFacade = customerDataProviderFacade
        self.projectService = projectService
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

        customerDataProviderFacade.votesProvider.addCacheObserver(self, deliverOn: .main,
                                                                  executing: changesBlock,
                                                                  failing: failBlock)
    }
}

extension ProjectsInteractor: ProjectsInteractorInputProtocol {
    func setup() {
        setupVotesDataProvider()
    }

    func refreshVotes() {
        customerDataProviderFacade.votesProvider.refreshCache()
    }

    func vote(for project: ProjectVote) {
        do {
            _ = try projectService.vote(with: project, runCompletionIn: .main) { (optionalResult) in
                if let result = optionalResult {
                    switch result {
                    case .success:
                        self.presenter?.didVote(for: project)
                    case .error(let error):
                        self.presenter?.didReceiveVote(error: error, for: project)
                    }
                }
            }
        } catch {
            presenter?.didReceiveVote(error: error, for: project)
        }
    }

    func toggleFavorite(for projectId: String) {
        do {
            _ = try projectService.toggleFavorite(projectId: projectId, runCompletionIn: .main) { (optionalResult) in
                if let result = optionalResult {
                    switch result {
                    case .success:
                        self.presenter?.didToggleFavorite(for: projectId)
                    case .error(let error):
                        self.presenter?.didReceiveTogglingFavorite(error: error, for: projectId)
                    }
                }
            }
        } catch {
            presenter?.didReceiveTogglingFavorite(error: error, for: projectId)
        }
    }
}
