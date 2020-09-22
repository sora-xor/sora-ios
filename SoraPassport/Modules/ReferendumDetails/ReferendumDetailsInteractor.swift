/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import RobinHood

final class ReferendumDetailsInteractor {
    weak var presenter: ReferendumDetailsInteractorOutputProtocol!

    let customerDataProviderFacade: CustomerDataProviderFacadeProtocol
    let referendumDetailsDataProvider: SingleValueProvider<ReferendumData>
    let projectService: ProjectUnitServiceProtocol
    let eventCenter: EventCenterProtocol

    init(customerDataProviderFacade: CustomerDataProviderFacadeProtocol,
         referendumDetailsDataProvider: SingleValueProvider<ReferendumData>,
         projectService: ProjectUnitServiceProtocol,
         eventCenter: EventCenterProtocol) {
        self.customerDataProviderFacade = customerDataProviderFacade
        self.referendumDetailsDataProvider = referendumDetailsDataProvider
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
                    break
                }
            }
        }

        let failBlock: (Error) -> Void = { [weak self] (error) in
            self?.presenter?.didReceiveVotesDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)

        customerDataProviderFacade.votesProvider.addObserver(self,
                                                             deliverOn: .main,
                                                             executing: changesBlock,
                                                             failing: failBlock,
                                                             options: options)
    }

    private func setupReferendumDetailsProvider() {
        let changesBlock: ([DataProviderChange<ReferendumData>]) -> Void = { [weak self] (changes) in
            if let change = changes.first {
                switch change {
                case .insert(let referendum):
                    self?.presenter?.didReceive(referendum: referendum)
                case .update(let referendum):
                    self?.presenter?.didReceive(referendum: referendum)
                case .delete:
                    break
                }
            }
        }

        let failBlock: (Error) -> Void = { [weak self] (error) in
            self?.presenter?.didReceiveVotesDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)

        referendumDetailsDataProvider.addObserver(self,
                                                  deliverOn: .main,
                                                  executing: changesBlock,
                                                  failing: failBlock,
                                                  options: options)
    }

    func setupEventCenter() {
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension ReferendumDetailsInteractor: ReferendumDetailsInteractorInputProtocol {
    func setup() {
        setupVotesDataProvider()
        setupReferendumDetailsProvider()
        setupEventCenter()
    }

    func refreshVotes() {
        customerDataProviderFacade.votesProvider.refresh()
    }

    func refreshDetails() {
        referendumDetailsDataProvider.refresh()
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
}

extension ReferendumDetailsInteractor: EventVisitorProtocol {
    func processReferendumVote(event: ReferendumVoteEvent) {
        presenter?.didVote(for: event.vote)
    }
}
