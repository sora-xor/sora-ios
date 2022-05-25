import Foundation

protocol ProfileViewProtocol: ControllerBackedProtocol {
    func didLoad(optionViewModels: [ProfileOptionViewModelProtocol])
}

protocol ProfilePresenterProtocol: AlertPresentable {
    func setup()
    func activateOption(at index: UInt)
}

protocol ProfileInteractorInputProtocol: class {
    func logoutAndClean()
}

protocol ProfileInteractorOutputProtocol: class {
    func restart()
}

protocol ProfileWireframeProtocol: ErrorPresentable, AlertPresentable, HelpPresentable, WebPresentable {
    func showPersonalDetailsView(from view: ProfileViewProtocol?)
    func showFriendsView(from view: ProfileViewProtocol?)
    func showPassphraseView(from view: ProfileViewProtocol?)
    func showChangePin(from view: ProfileViewProtocol?)
    func showLanguageSelection(from view: ProfileViewProtocol?)
    func showFaq(from view: ProfileViewProtocol?)
    func showAbout(from view: ProfileViewProtocol?)
    func showDisclaimer(from view: ProfileViewProtocol?)
    func showLogout(from view: ProfileViewProtocol?, completionBlock: (() -> Void)?)
    func switchBiometry(
        toValue: Bool,
        from view: ProfileViewProtocol?,
        successBlock: @escaping (Bool) -> Void
    )
    func showRoot()
}

protocol ProfileViewFactoryProtocol: class {
	static func createView() -> ProfileViewProtocol?
}
