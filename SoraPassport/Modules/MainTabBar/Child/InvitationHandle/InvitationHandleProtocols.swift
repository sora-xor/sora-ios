import Foundation

protocol InvitationHandlePresenterProtocol: ChildPresenterProtocol, DeepLinkNavigatorProtocol {}

protocol InvitationHandleInteractorInputProtocol: class {
    func setup()
    func refresh()
    func apply(invitationCode: String)
}

protocol InvitationHandleInteractorOutputProtocol: class {
    func didReceive(userData: UserData)
    func didReceiveUserDataProvider(error: Error)

    func didApply(invitationCode: String)
    func didReceiveInvitationApplication(error: Error, of code: String)
}

protocol InvitationHandleWireframeProtocol: AlertPresentable, ErrorPresentable {}

protocol InvitationHandlePresenterFactoryProtocol {
    static func createPresenter(for view: ControllerBackedProtocol) -> InvitationHandlePresenterProtocol?
}
