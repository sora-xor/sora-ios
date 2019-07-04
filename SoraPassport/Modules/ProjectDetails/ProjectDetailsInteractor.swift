/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

final class ProjectDetailsInteractor {
	weak var presenter: ProjectDetailsInteractorOutputProtocol?

    private var customerDataProviderFacade: CustomerDataProviderFacadeProtocol
    private var projectDetailsDataProvider: SingleValueProvider<ProjectDetailsData, CDSingleValue>
    private var projectService: ProjectUnitServiceProtocol

    init(customerDataProviderFacade: CustomerDataProviderFacadeProtocol,
         projectDetailsDataProvider: SingleValueProvider<ProjectDetailsData, CDSingleValue>,
         projectService: ProjectUnitServiceProtocol) {
        self.customerDataProviderFacade = customerDataProviderFacade
        self.projectDetailsDataProvider = projectDetailsDataProvider
        self.projectService = projectService
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
}

extension ProjectDetailsInteractor: ProjectDetailsInteractorInputProtocol {
    func setup() {
        setupVotesDataProvider()
        setupProjectDetailsProvider()
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
                        self.presenter?.didToggleFavorite(for: projectId)
                    case .error(let error):
                        self.presenter?.didReceiveToggleFavorite(error: error, for: projectId)
                    }
                }
            }
        } catch {
            presenter?.didReceiveToggleFavorite(error: error, for: projectId)
        }
    }
}
