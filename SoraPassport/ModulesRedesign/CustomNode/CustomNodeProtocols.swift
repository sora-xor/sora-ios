import XNetworking
import SoraFoundation

// MARK: - View

protocol CustomNodeViewProtocol: ControllerBackedProtocol {
    func changeSubmitButton(to isEnabled: Bool)
    func showNameTextField(_ error: String)
    func showAddressTextField(_ error: String)
    func updateFields(name: String, url: String)
    func resetState()
}

// MARK: - Presenter

protocol CustomNodePresenterProtocol: AlertPresentable {
    func setup()
    func chestButtonTapped()
    func howToRunButtonTapped()
    func customNodeNameChange(to text: String)
    func customNodeAddressChange(to text: String)
    func submitButtonTapped()
}

// MARK: - Interactor

protocol CustomNodeInteractorInputProtocol: AnyObject {
    func updateCustomNode(url: URL, name: String)
}

protocol CustomNodeInteractorOutputProtocol: AnyObject {
    func didCompleteAdding(in chain: ChainModel)
    func didReceive(error: AddConnectionError)
}

// MARK: - Wireframe

protocol CustomNodeWireframeProtocol {
    func showRoot()
    func showAddCustomNode()
}

// MARK: - Factory

protocol CustomNodeViewFactoryProtocol: AnyObject {
    static func createView() -> CustomNodeViewProtocol?
}
