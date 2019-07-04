/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

final class ReputationInteractor {
	weak var presenter: ReputationInteractorOutputProtocol?

    private(set) var customerDataProviderFacade: CustomerDataProviderFacadeProtocol

    init(customerDataProviderFacade: CustomerDataProviderFacadeProtocol) {
        self.customerDataProviderFacade = customerDataProviderFacade
    }

    private func setupReputationDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<ReputationData>]) in
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

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        customerDataProviderFacade.reputationDataProvider.addCacheObserver(self,
                                                                           deliverOn: .main,
                                                                           executing: changesBlock,
                                                                           failing: failBlock,
                                                                           options: options)
    }

    private func setupVotesDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<VotesData>]) in
            if let change = changes.first {
                switch change {
                case .insert(let votesData):
                    self?.presenter?.didReceive(votesData: votesData)
                case .update(let votesData):
                    self?.presenter?.didReceive(votesData: votesData)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveVotesDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false)
        customerDataProviderFacade.votesProvider.addCacheObserver(self,
                                                                  deliverOn: .main,
                                                                  executing: changesBlock,
                                                                  failing: failBlock,
                                                                  options: options)
    }
}

extension ReputationInteractor: ReputationInteractorInputProtocol {
    func setup() {
        setupReputationDataProvider()
        setupVotesDataProvider()
    }

    func refreshReputation() {
        customerDataProviderFacade.reputationDataProvider.refreshCache()
        customerDataProviderFacade.votesProvider.refreshCache()
    }
}
