/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class ReputationInteractor {
	weak var presenter: ReputationInteractorOutputProtocol?

    let reputationProvider: SingleValueProvider<ReputationData, CDSingleValue>
    let reputationDetailsProvider: SingleValueProvider<ReputationDetailsData, CDSingleValue>
    let votesProvider: SingleValueProvider<VotesData, CDSingleValue>

    init(reputationProvider: SingleValueProvider<ReputationData, CDSingleValue>,
         reputationDetailsProvider: SingleValueProvider<ReputationDetailsData, CDSingleValue>,
         votesProvider: SingleValueProvider<VotesData, CDSingleValue>) {
        self.reputationProvider = reputationProvider
        self.reputationDetailsProvider = reputationDetailsProvider
        self.votesProvider = votesProvider
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
        reputationProvider.addCacheObserver(self,
                                            deliverOn: .main,
                                            executing: changesBlock,
                                            failing: failBlock,
                                            options: options)
    }

    private func setupReputationDetailsProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<ReputationDetailsData>]) in
            if let change = changes.first {
                switch change {
                case .insert(let details):
                    self?.presenter?.didReceive(reputationDetails: details)
                case .update(let details):
                    self?.presenter?.didReceive(reputationDetails: details)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveReputationDetailsDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        reputationDetailsProvider.addCacheObserver(self,
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
        votesProvider.addCacheObserver(self,
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
        setupReputationDetailsProvider()
    }

    func refresh() {
        reputationProvider.refreshCache()
        reputationDetailsProvider.refreshCache()
        votesProvider.refreshCache()
    }
}
