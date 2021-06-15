import Foundation
import RobinHood

final class FriendsInteractor {
    weak var presenter: FriendsInteractorOutputProtocol?

//    private(set) var customerDataProviderFacade: CustomerDataProviderFacadeProtocol
    private(set) var eventCenter: EventCenterProtocol

    init(//customerDataProviderFacade: CustomerDataProviderFacadeProtocol,
         eventCenter: EventCenterProtocol) {
//        self.customerDataProviderFacade = customerDataProviderFacade
        self.eventCenter = eventCenter
    }

    private func setupUserDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<UserData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let user):
                    self?.presenter?.didLoad(user: user)
                case .update(let user):
                    self?.presenter?.didLoad(user: user)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveUserDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
//
//        customerDataProviderFacade.userProvider.addObserver(
//            self, deliverOn: .main, executing: changesBlock, failing: failBlock, options: options
//        )
    }

    private func setupInvitationsDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<ActivatedInvitationsData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let invitations):
                    self?.presenter?.didLoad(invitationsData: invitations)
                case .update(let invitations):
                    self?.presenter?.didLoad(invitationsData: invitations)
                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveInvitedUsersDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

//        customerDataProviderFacade.friendsDataProvider.addObserver(
//            self, deliverOn: .main, executing: changesBlock, failing: failBlock, options: options
//        )
    }
}

extension FriendsInteractor: FriendsInteractorInputProtocol {
    func setup() {
        setupUserDataProvider()
        setupInvitationsDataProvider()

//        eventCenter.add(observer: self)
    }

    func refreshUser() {
//        customerDataProviderFacade.userProvider.refresh()
    }

    func refreshInvitedUsers() {
//        customerDataProviderFacade.friendsDataProvider.refresh()
    }

    func apply(invitationCode: String) {
        eventCenter.notify(with: InvitationInputEvent(code: invitationCode))
    }
}
//
//extension FriendsInteractor: EventVisitorProtocol {
//    func processInvitationApplied(event: InvitationAppliedEvent) {
//        refreshUser()
//        refreshInvitedUsers()
//    }
//}
