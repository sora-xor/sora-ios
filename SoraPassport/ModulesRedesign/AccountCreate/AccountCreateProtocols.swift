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
    func skip()
}

protocol AccountCreateInteractorInputProtocol: AnyObject {
    func setup()
    func skipConfirmation(request: AccountCreationRequest, mnemonic: IRMnemonicProtocol)
}

protocol AccountCreateInteractorOutputProtocol: AnyObject {
    func didReceive(metadata: AccountCreationMetadata)
    func didReceiveMnemonicGeneration(error: Swift.Error)
    func didReceive(words: [String], afterConfirmationFail: Bool)
    func didCompleteConfirmation()
    func didReceive(error: Swift.Error)
}

protocol AccountCreateWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting, Authorizable {
    func proceed(on controller: UIViewController?)
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
    static func createViewForAdding(username: String, endAddingBlock: (() -> Void)?) -> AccountCreateViewProtocol? 
//    static func createViewForConnection(item: ConnectionItem, username: String) -> AccountCreateViewProtocol?
}
