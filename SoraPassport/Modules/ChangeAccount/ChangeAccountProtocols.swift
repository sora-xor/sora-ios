import UIKit

protocol ChangeAccountViewProtocol: ControllerBackedProtocol {
    func didLoad(accountViewModels: [AccountViewModelProtocol])
    func update(with accountViewModels: [AccountViewModelProtocol])
    func scrollViewToBottom()
}

protocol ChangeAccountPresenterProtocol: AnyObject {
    func setup()
    func selectItem(at index: Int)
    func createAccount()
    func importAccount()
    func endUpdating()
}

protocol ChangeAccountInteractorInputProtocol: AnyObject {
    func getAccounts()
}

protocol ChangeAccountInteractorOutputProtocol: AnyObject {
    func received(accounts: [AccountItem])
}

protocol ChangeAccountWireframeProtocol: AnyObject {
    func showSignUp(from view: UIViewController, completion: @escaping () -> Void)
    func showAccountRestore(from view: UIViewController, completion: @escaping () -> Void)
}

protocol ChangeAccountViewFactoryProtocol: AnyObject {
    static func changeAccountViewController(with completion: @escaping () -> Void) -> ChangeAccountViewProtocol?
}
