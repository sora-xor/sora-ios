import UIKit

protocol ChangeAccountViewProtocol: ControllerBackedProtocol {
    var presenter: ChangeAccountPresenterProtocol? { get set }
    
    func update(with accountViewModels: [AccountMenuItem])
}

protocol ChangeAccountPresenterProtocol: AnyObject {
    var view: ChangeAccountViewProtocol? { get set }
    
    func reload()
    func selectItem(at index: Int)
    func editItem(at index: Int)
    func createAccount()
    func importAccount()
    func addOrCreateAccount()
    func endUpdating()
}

protocol ChangeAccountWireframeProtocol: AnyObject {
    func showStart(from view: UIViewController, completion: @escaping () -> Void)
    func showEdit(account: AccountItem, from controller: UIViewController)
    func showSignUp(from view: UIViewController, completion: @escaping () -> Void)
    func showAccountRestore(from view: UIViewController, completion: @escaping () -> Void)
}

protocol ChangeAccountViewFactoryProtocol: AnyObject {
    static func changeAccountViewController(with completion: @escaping () -> Void) -> ChangeAccountViewProtocol?
}
