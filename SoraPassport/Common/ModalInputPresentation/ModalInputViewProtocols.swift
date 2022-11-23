import Foundation

public protocol ModalInputViewProtocol: class {
    var presenter: ModalInputViewPresenterProtocol? { get set }
}

public protocol ModalInputViewPresenterProtocol: class {
    func hide(view: ModalInputViewProtocol, animated: Bool)
}
