/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

final class VotesHistoryInteractor {
	weak var presenter: VotesHistoryInteractorOutputProtocol?

    private(set) var votesHistoryDataProvider: SingleValueProvider<[VotesHistoryEventData], CDSingleValue>
    private(set) var projectService: ProjectUnitFundingProtocol

    init(votesHistoryDataProvider: SingleValueProvider<[VotesHistoryEventData], CDSingleValue>,
         projectService: ProjectUnitFundingProtocol) {
        self.votesHistoryDataProvider = votesHistoryDataProvider
        self.projectService = projectService
    }

    private func setupVotesHistoryDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<[VotesHistoryEventData]>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let votesHistory), .update(let votesHistory):
                    self?.presenter?.didReload(events: votesHistory)
                default:
                    break
                }
            } else {
                self?.presenter?.didReload(events: nil)
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveVotesHistoryDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        votesHistoryDataProvider.addCacheObserver(self,
                                                  deliverOn: .main,
                                                  executing: changesBlock,
                                                  failing: failBlock,
                                                  options: options)
    }
}

extension VotesHistoryInteractor: VotesHistoryInteractorInputProtocol {
    func setup() {
        setupVotesHistoryDataProvider()
    }

    func reload() {
        votesHistoryDataProvider.refreshCache()
    }

    func loadNext(page: Pagination) {
        do {
            _ = try projectService.fetchVotesHistory(with: page,
                                                     runCompletionIn: .main) { [weak self] (optionalResult) in
                if let result = optionalResult {
                    switch result {
                    case .success(let events):
                        self?.presenter?.didLoadNext(events: events, for: page)
                    case .error(let error):
                        self?.presenter?.didReceiveLoadNext(error: error, for: page)
                    }
                }
            }
        } catch {
            presenter?.didReceiveLoadNext(error: error, for: page)
        }
    }
}
