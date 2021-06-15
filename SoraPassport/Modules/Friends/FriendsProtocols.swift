// MARK: - View

protocol FriendsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(friendsViewModel: FriendsInvitationViewModelProtocol)
    func didReceive(rewardsViewModels: [RewardsViewModelProtocol])
    func didChange(applyInviteTitle: String)
}

// MARK: - Presenter

protocol FriendsPresenterProtocol: AlertPresentable {
    func setup()
    func viewDidAppear()
    func didSelectAction(_ action: FriendsPresenter.InvitationActionType)
}

// MARK: - Interactor

protocol FriendsInteractorInputProtocol: class {
    func setup()
    func refreshUser()
    func refreshInvitedUsers()
    func apply(invitationCode: String)
}

protocol FriendsInteractorOutputProtocol: class {
    func didLoad(user: UserData)
    func didReceiveUserDataProvider(error: Error)
    func didLoad(invitationsData: ActivatedInvitationsData)
    func didReceiveInvitedUsersDataProvider(error: Error)
}

// MARK: - Wireframe

protocol FriendsWireframeProtocol: SharingPresentable, AlertPresentable,
                                   ErrorPresentable, HelpPresentable, InputFieldPresentable {

}

// MARK: - Factory

protocol FriendsViewFactoryProtocol: class {
    static func createView() -> FriendsViewProtocol?
}
