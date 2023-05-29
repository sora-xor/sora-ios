import Foundation

public protocol ModalInputViewProtocol: AnyObject {
    var presenter: ModalInputViewPresenterProtocol? { get set }
}

public protocol ModalInputViewPresenterProtocol: AnyObject {
    func hide(view: ModalInputViewProtocol, animated: Bool)
}
