import Foundation
import CommonWallet

protocol ProfileViewProtocol: ControllerBackedProtocol {
    func didLoad(optionsViewModels: [ProfileOptionsHeaderViewModelProtocol])
}

protocol ProfilePresenterProtocol: AlertPresentable {
    func setup()
    func activateOption(_ option: ProfileOption)
}

protocol ProfileInteractorInputProtocol: AnyObject {
    var isThereEntropy: Bool { get }
    func logoutAndClean()
    func getCurrentNodeName(completion: @escaping (String) -> Void)
    func isLastAccountWithCustomNodes(completion: @escaping (Bool) -> Void)
}

protocol ProfileInteractorOutputProtocol: AnyObject {
    func restart()
    func updateScreen()
}

protocol ProfileWireframeProtocol: ErrorPresentable, AlertPresentable, HelpPresentable, WebPresentable {
    func showChangeAccountView(from view: ProfileViewProtocol?, completion: @escaping () -> Void)
    func showPersonalDetailsView(from view: ProfileViewProtocol?, completion: @escaping () -> Void)
    func showFriendsView(from view: ProfileViewProtocol?)
    func showPassphraseView(from view: ProfileViewProtocol?)
    func showChangePin(from view: ProfileViewProtocol)
    func showLanguageSelection(from view: ProfileViewProtocol?)
    func showFaq(from view: ProfileViewProtocol?)
    func showAbout(from view: ProfileViewProtocol?)
    func showDisclaimer(from view: ProfileViewProtocol?)
    func showLogout(from view: ProfileViewProtocol?, isNeedCustomNodeText: Bool, completionBlock: (() -> Void)?)
    func showNodes(from view: ProfileViewProtocol?)
    func switchBiometry(
        toValue: Bool,
        from view: ProfileViewProtocol?,
        successBlock: @escaping (Bool) -> Void
    )
    func showRoot()
}

protocol ProfileViewFactoryProtocol: AnyObject {
    static func createView(walletContext: CommonWalletContextProtocol) -> ProfileViewProtocol?
}
