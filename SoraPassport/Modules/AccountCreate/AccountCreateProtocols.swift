import IrohaCrypto
import SoraFoundation

protocol AccountCreateViewProtocol: ControllerBackedProtocol {
    func set(mnemonic: [String])
}

protocol AccountCreatePresenterProtocol: AnyObject {
    func setup()
    func activateInfo()
    func proceed()
    func share()
    func restoredApp()
}

protocol AccountCreateInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AccountCreateInteractorOutputProtocol: AnyObject {
    func didReceive(metadata: AccountCreationMetadata)
    func didReceiveMnemonicGeneration(error: Swift.Error)
}

protocol AccountCreateWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting, Authorizable {
    func confirm(from view: AccountCreateViewProtocol?,
                 request: AccountCreationRequest,
                 metadata: AccountCreationMetadata)
}

protocol Authorizable {
    func authorize()
}

extension Authorizable {
    func authorize() {}
}

protocol AccountCreateViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(username: String) -> AccountCreateViewProtocol?
    static func createViewForAdding(username: String) -> AccountCreateViewProtocol?
    static func createViewForAdding(username: String, endAddingBlock: (() -> Void)?) -> AccountCreateViewProtocol? 
//    static func createViewForConnection(item: ConnectionItem, username: String) -> AccountCreateViewProtocol?
}
