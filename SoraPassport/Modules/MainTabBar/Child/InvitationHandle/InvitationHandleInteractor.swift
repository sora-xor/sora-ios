import Foundation
import RobinHood

final class InvitationHandleInteractor {
    weak var presenter: InvitationHandleInteractorOutputProtocol?

    let userDataProvider: SingleValueProvider<UserData>
//    let projectService: ProjectUnitServiceProtocol
    let eventCenter: EventCenterProtocol

    init(//projectService: ProjectUnitServiceProtocol,
         userDataProvider: SingleValueProvider<UserData>,
         eventCenter: EventCenterProtocol) {
//        self.projectService = projectService
        self.userDataProvider = userDataProvider
        self.eventCenter = eventCenter
    }

    private func setupUserDataProvider() {
        let changesClosure = { [weak self] (changes: [DataProviderChange<UserData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let userData):
                    self?.presenter?.didReceive(userData: userData)
                case .update(let userData):
                    self?.presenter?.didReceive(userData: userData)
                default:
                    break
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveUserDataProvider(error: error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                  waitsInProgressSyncOnAdd: false)

        userDataProvider.addObserver(self,
                                     deliverOn: .main,
                                     executing: changesClosure,
                                     failing: failureClosure,
                                     options: options)
    }
}

extension InvitationHandleInteractor: InvitationHandleInteractorInputProtocol {
    func setup() {
        setupUserDataProvider()

//        eventCenter.add(observer: self)
    }

    func refresh() {
        userDataProvider.refresh()
    }

    func apply(invitationCode: String) {
//        do {
//            _ = try projectService.applyInvitation(code: invitationCode,
//                                                   runCompletionIn: .main) { [weak self] (result) in
//                if let result = result {
//                    switch result {
//                    case .success:
//                        self?.presenter?.didApply(invitationCode: invitationCode)
//                        self?.eventCenter.notify(with: InvitationAppliedEvent(code: invitationCode))
//                    case .failure(let error):
//                        self?.presenter?.didReceiveInvitationApplication(error: error,
//                                                                         of: invitationCode)
//
//                    }
//                }
//            }
//        } catch {
//            presenter?.didReceiveInvitationApplication(error: error, of: invitationCode)
//        }
    }
}
//
//extension InvitationHandleInteractor: EventVisitorProtocol {
//    func processInvitationInput(event: InvitationInputEvent) {
//        apply(invitationCode: event.code)
//    }
//}
