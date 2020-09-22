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

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)

        customerDataProviderFacade.userProvider.addObserver(self,
                                                            deliverOn: .main,
                                                            executing: changesBlock,
                                                            failing: failBlock,
                                                            options: options)
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

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)

        customerDataProviderFacade.votesProvider.addObserver(self,
                                                             deliverOn: .main,
                                                             executing: changesBlock,
                                                             failing: failBlock,
                                                             options: options)
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

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)

        customerDataProviderFacade.reputationDataProvider.addObserver(self,
                                                                      deliverOn: .main,
                                                                      executing: changesBlock,
                                                                      failing: failBlock,
                                                                      options: options)
    }
}

extension ProfileInteractor: ProfileInteractorInputProtocol {
    func setup() {
        setupUserDataProvider()
        setupVotesDataProvider()
        setupReputationDataProvider()
    }

    func refreshUser() {
        customerDataProviderFacade.userProvider.refresh()
    }

    func refreshVotes() {
        customerDataProviderFacade.votesProvider.refresh()
    }

    func refreshReputation() {
        customerDataProviderFacade.reputationDataProvider.refresh()
    }
}
