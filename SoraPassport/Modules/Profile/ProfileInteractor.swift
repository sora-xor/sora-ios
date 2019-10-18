/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class ProfileInteractor {
	weak var presenter: ProfileInteractorOutputProtocol?

    private(set) var customerDataProviderFacade: CustomerDataProviderFacadeProtocol

    init(customerDataProviderFacade: CustomerDataProviderFacadeProtocol) {
        self.customerDataProviderFacade = customerDataProviderFacade
    }

    private func setupUserDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<UserData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let user):
                    self?.presenter?.didReceive(userData: user)
                case .update(let user):
                    self?.presenter?.didReceive(userData: user)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveUserDataProvider(error: error)
        }

        customerDataProviderFacade.userProvider.addCacheObserver(self,
                                                               deliverOn: .main,
                                                               executing: changesBlock,
                                                               failing: failBlock)
    }

    private func setupVotesDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<VotesData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let votes):
                    self?.presenter?.didReceive(votesData: votes)
                case .update(let votes):
                    self?.presenter?.didReceive(votesData: votes)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveVotesDataProvider(error: error)
        }

        customerDataProviderFacade.votesProvider.addCacheObserver(self,
                                                                 deliverOn: .main,
                                                                 executing: changesBlock,
                                                                 failing: failBlock)
    }

    private func setupReputationDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<ReputationData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let reputation):
                    self?.presenter?.didReceive(reputationData: reputation)
                case .update(let reputation):
                    self?.presenter?.didReceive(reputationData: reputation)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveReputationDataProvider(error: error)
        }

        customerDataProviderFacade.reputationDataProvider.addCacheObserver(self,
                                                                           deliverOn: .main,
                                                                           executing: changesBlock,
                                                                           failing: failBlock)
    }
}

extension ProfileInteractor: ProfileInteractorInputProtocol {
    func setup() {
        setupUserDataProvider()
        setupVotesDataProvider()
        setupReputationDataProvider()
    }

    func refreshUser() {
        customerDataProviderFacade.userProvider.refreshCache()
    }

    func refreshVotes() {
        customerDataProviderFacade.votesProvider.refreshCache()
    }

    func refreshReputation() {
        customerDataProviderFacade.reputationDataProvider.refreshCache()
    }
}
